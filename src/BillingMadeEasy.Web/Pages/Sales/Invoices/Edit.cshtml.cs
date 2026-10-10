using BillingMadeEasy.Core.Modules;
using BillingMadeEasy.Core.Parties;
using BillingMadeEasy.Web.Features.Business;
using BillingMadeEasy.Web.Features.Catalog;
using BillingMadeEasy.Web.Features.Parties;
using BillingMadeEasy.Web.Features.Sales;
using BillingMadeEasy.Web.Infrastructure.Formatting;
using BillingMadeEasy.Web.Infrastructure.Modules;
using BillingMadeEasy.Web.Infrastructure.Pages;
using Microsoft.AspNetCore.Mvc;

namespace BillingMadeEasy.Web.Pages.Sales.Invoices;

public sealed class EditModel(
    InvoiceStore invoices, InvoiceBuilder builder, BusinessStore business, PartyStore parties,
    CatalogStore catalog, EntitlementService entitlements) : TenantPageModel
{
    [BindProperty(SupportsGet = true)] public long? Id { get; set; }

    public InvoiceForm Form { get; private set; } = new();
    public string? CustomerLabel { get; private set; }
    public IReadOnlyList<ProfileRow> Profiles { get; private set; } = [];
    public IReadOnlyList<TaxOption> TaxRates { get; private set; } = [];
    public IReadOnlyList<StateOption> States { get; private set; } = [];
    public IReadOnlyList<UnitOption> Units { get; private set; } = [];
    public IReadOnlyList<PartyLocation> Locations { get; private set; } = [];
    public BusinessProfile? Profile { get; private set; }
    public DateTime? SavedAtUtc { get; private set; }

    public bool IsNew => Id is null or 0;
    public bool CanIssue => Can("Sales.Invoice.Issue");
    public DateOnly Today => DateOnly.FromDateTime(When.TodayIst());

    public async Task<IActionResult> OnGetAsync(long? copy, long? partyId, CancellationToken ct)
    {
        if (IsNew)
        {
            if (!Can("Sales.Invoice.Create")) return Forbid();
            var (profile, _) = await business.GetAsync(TenantId, null, ct);
            if (profile is null) return RedirectToPage("/Business/Index");
            Form = new InvoiceForm
            {
                BusinessProfileId = profile.BusinessProfileId,
                InvoiceDate = Today,
                DueDate = profile.DefaultDueDays is short d && d > 0 ? Today.AddDays(d) : null,
                Terms = profile.InvoiceTerms,
                Notes = profile.InvoiceNote,
            };
            if (copy is long source && await invoices.GetAsync(TenantId, source, ct) is ({ } original, var lines))
            {
                // A repeat invoice: same customer and lines, today's date, prices as they were.
                Form = FromInvoice(original, lines);
                Form.InvoiceDate = Today;
                Form.DueDate = profile.DefaultDueDays is short dd && dd > 0 ? Today.AddDays(dd) : null;
                CustomerLabel = original.BuyerName;
            }
            else if (partyId is long pid && await parties.GetAsync(TenantId, pid, ct) is { } party)
            {
                Form.PartyId = pid;
                CustomerLabel = party.Party.DisplayName;
            }
        }
        else
        {
            var (invoice, lines) = await invoices.GetAsync(TenantId, Id!.Value, ct);
            if (invoice is null) return NotFound();
            if (!invoice.IsDraft) return Redirect($"/Sales/Invoices/View/{Id}");
            if (!Can("Sales.Invoice.Edit") && !Can("Sales.Invoice.Create")) return Forbid();
            Form = FromInvoice(invoice, lines);
            CustomerLabel = invoice.PartyId is null ? null : invoice.BuyerName;
            SavedAtUtc = invoice.UpdatedAtUtc ?? invoice.CreatedAtUtc;
        }
        if (Form.Lines.Count == 0) Form.Lines.Add(new LineForm { Quantity = 1 });
        await LoadAsync(ct);
        return Page();
    }

    public async Task<IActionResult> OnPostAsync([FromForm(Name = "Form")] InvoiceForm form, string? then, CancellationToken ct)
    {
        if (IsNew ? !Can("Sales.Invoice.Create") : !(Can("Sales.Invoice.Edit") || Can("Sales.Invoice.Create"))) return Forbid();
        Form = form;
        bool issue = then == "issue";
        if (issue && !CanIssue) return Forbid();

        if (ModelState.IsValid)
        {
            var built = await builder.BuildAsync(TenantId, Id ?? 0, form, UserId, IpAddress, ct);
            foreach (var (field, message) in built.Problems) ModelState.AddModelError(field, message);

            if (built.Ok)
            {
                var saved = await invoices.SaveAsync(built.SaveParameters!, ct);
                if (!saved.Succeeded)
                    ModelState.AddModelError(saved.FieldName is null ? "" : "Form." + saved.FieldName, saved.ResultMessage + ".");
                else if (!issue)
                {
                    Flash = "Draft saved. It has no number until it's issued.";
                    return Redirect($"/Sales/Invoices/Edit/{saved.SalesInvoiceId}");
                }
                else
                {
                    Id = saved.SalesInvoiceId;
                    var problem = await IssueAsync(saved.SalesInvoiceId, form.BusinessProfileId, ct);
                    if (problem is null) return Redirect($"/Sales/Invoices/View/{saved.SalesInvoiceId}");
                    // Saved as a draft, but not issued: say why, keep them on the form.
                    Flash = problem;
                    return Redirect($"/Sales/Invoices/Edit/{saved.SalesInvoiceId}");
                }
            }
        }

        if (form.PartyId is long pid && await parties.GetAsync(TenantId, pid, ct) is { } party) CustomerLabel = party.Party.DisplayName;
        if (Form.Lines.Count == 0) Form.Lines.Add(new LineForm { Quantity = 1 });
        await LoadAsync(ct);
        return Page();
    }

    /// <summary>Issues a saved draft. Returns why it couldn't be issued, or null.</summary>
    private async Task<string?> IssueAsync(long invoiceId, long profileId, CancellationToken ct)
    {
        var (profile, accounts) = await business.GetAsync(TenantId, profileId, ct);
        if (profile is null) return "Choose which of your businesses this invoice is from.";
        int? limit = (await entitlements.GetAsync(TenantId, ct)).Limit(Meters.InvoicesPerMonth);
        var result = await invoices.IssueAsync(TenantId, invoiceId, Seller.From(profile, accounts).ToJson(), Today, limit, UserId, IpAddress, ct);
        if (!result.Succeeded) return "Saved as a draft but not issued: " + result.ResultMessage + ".";
        Flash = $"Issued {result.InvoiceNumber}. Print it, or send it to the customer.";
        return null;
    }

    public async Task<IActionResult> OnPostDiscardAsync(CancellationToken ct)
    {
        if (IsNew) return Redirect("/Sales/Invoices");
        var result = await invoices.CancelAsync(TenantId, Id!.Value, null, UserId, IpAddress, ct);
        Flash = result.Succeeded ? "Draft discarded." : result.ResultMessage + ".";
        return Redirect(result.Succeeded ? "/Sales/Invoices" : $"/Sales/Invoices/View/{Id}");
    }

    // ── Lookups for the form ──

    public async Task<IActionResult> OnGetCustomersAsync(string? q, CancellationToken ct)
    {
        var page = await parties.ListAsync(TenantId, PartyCodes.RoleCustomer, q, 1, 8, ct);
        return new JsonResult(page.Rows.Select(p => new { id = p.PartyId, name = p.DisplayName, city = p.PrimaryCity, onHold = p.Status != PartyCodes.StatusActive }));
    }

    public async Task<IActionResult> OnGetCustomerAsync(long partyId, CancellationToken ct)
    {
        var d = await parties.GetAsync(TenantId, partyId, ct);
        if (d is null) return NotFound();
        var billing = d.Addresses.FirstOrDefault(a => a.AddressType == PartyCodes.AddressBilling && a.IsDefault)
                      ?? d.Addresses.FirstOrDefault(a => a.IsDefault) ?? d.Addresses.FirstOrDefault();
        return new JsonResult(new
        {
            id = d.Party.PartyId,
            name = d.Party.DisplayName,
            legalName = d.Party.LegalName,
            phone = d.Party.Phone,
            email = d.Party.Email,
            onHold = d.Party.Status != PartyCodes.StatusActive || !d.Party.IsActive,
            address = billing?.OneLine,
            stateCode = billing?.StateCode,
            locations = d.Locations.Select(l =>
            {
                var addr = d.Addresses.FirstOrDefault(a => a.PartyAddressId == l.AddressId);
                return new { id = l.PartyLocationId, name = l.LocationName, gstin = l.Gstin, stateCode = StateOf(l), stateName = l.StateName, address = addr?.OneLine, isDefault = l.IsDefault };
            }),
        });
    }

    public async Task<IActionResult> OnGetItemsAsync(string? q, long? partyId, CancellationToken ct) =>
        new JsonResult(await invoices.FindItemsAsync(TenantId, q, partyId, ct));

    public async Task<IActionResult> OnGetItemAsync(long offeringId, long? partyId, decimal? qty, DateOnly? date, CancellationToken ct)
    {
        var item = await invoices.ItemForAsync(TenantId, offeringId, partyId, qty is > 0 ? qty.Value : 1, date ?? Today, ct);
        if (item is null || !item.Succeeded) return NotFound();
        bool showPrice = Can("Catalog.Price.View") || Can("Sales.Invoice.Create");
        return new JsonResult(new
        {
            id = item.OfferingId,
            name = item.OfferingName,
            hsn = item.HsnSacCode,
            unit = item.UnitCode,
            taxRateId = item.TaxRateId,
            pureAgent = item.IsPureAgent,
            price = showPrice ? item.Price : null,
            inclusive = item.IsPriceInclusive,
            source = item.Source == "Default" ? "Standard price" : item.PriceListName ?? item.Source,
            standard = showPrice ? item.DefaultPrice : null,
            lastPrice = item.LastSoldPrice,
            lastOn = item.LastSoldOn?.ToString("d MMM yyyy"),
            lastInvoice = item.LastInvoiceNo,
        });
    }

    /// <summary>The registered state from the GSTIN, else the branch address's state.</summary>
    public static string? StateOf(PartyLocation l) =>
        BillingMadeEasy.Core.Tax.Gstin.IsValid(l.Gstin) ? BillingMadeEasy.Core.Tax.Gstin.StateCode(l.Gstin!) : l.StateCode;

    private async Task LoadAsync(CancellationToken ct)
    {
        Profiles = (await business.ListAsync(TenantId, ct)).Where(p => p.IsActive).ToList();
        (Profile, _) = await business.GetAsync(TenantId, Form.BusinessProfileId == 0 ? null : Form.BusinessProfileId, ct);
        TaxRates = await builder.TaxRatesOnAsync(TenantId, Form.InvoiceDate ?? Today, ct);
        States = await parties.StatesAsync(ct);
        Units = await catalog.UnitsAsync(TenantId, ct);
        if (Form.PartyId is long pid && await parties.GetAsync(TenantId, pid, ct) is { } party) Locations = party.Locations;
    }

    private static InvoiceForm FromInvoice(Invoice i, IReadOnlyList<InvoiceLine> lines) => new()
    {
        BusinessProfileId = i.BusinessProfileId,
        PartyId = i.PartyId,
        PartyLocationId = i.PartyLocationId,
        BuyerName = i.BuyerName,
        BuyerGstin = i.BuyerGstin,
        BuyerAddress = i.BuyerAddress,
        BuyerStateCode = i.BuyerStateCode,
        BuyerPhone = i.BuyerPhone,
        BuyerEmail = i.BuyerEmail,
        ShipElsewhere = i.ShipToAddress is not null || i.ShipToStateCode is not null,
        ShipToName = i.ShipToName,
        ShipToAddress = i.ShipToAddress,
        ShipToStateCode = i.ShipToStateCode,
        PlaceOfSupply = i.PlaceOfSupply,
        InvoiceDate = DateOnly.FromDateTime(i.InvoiceDate),
        DueDate = i.DueDate is { } d ? DateOnly.FromDateTime(d) : null,
        PoNumber = i.PoNumber,
        PoDate = i.PoDate is { } p ? DateOnly.FromDateTime(p) : null,
        IsReverseCharge = i.IsReverseCharge,
        Notes = i.Notes,
        Terms = i.Terms,
        Lines = lines.Select(l => new LineForm
        {
            OfferingId = l.OfferingId,
            Description = l.Description,
            HsnSacCode = l.HsnSacCode,
            Quantity = l.Quantity / 1.0000000000000000000000000000m,
            UnitCode = l.UnitCode,
            Rate = l.Rate / 1.0000000000000000000000000000m,
            RateIncludesTax = l.RateIncludesTax,
            DiscountPercent = l.DiscountPercent == 0 ? null : l.DiscountPercent / 1.0000000000000000000000000000m,
            TaxRateId = l.TaxRateId,
            PriceSource = l.PriceSource,
        }).ToList(),
    };
}

/// <summary>One line of the editor grid. Index is "__i__" in the template used for new rows.</summary>
public sealed record LineView(string Index, LineForm Line, IReadOnlyList<TaxOption> Rates, long? DefaultTaxRateId);
