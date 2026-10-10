using System.ComponentModel.DataAnnotations;
using System.Text.Json;
using BillingMadeEasy.Core.Billing;
using BillingMadeEasy.Core.Parties;
using BillingMadeEasy.Core.Tax;
using BillingMadeEasy.Data;
using BillingMadeEasy.Web.Features.Business;
using BillingMadeEasy.Web.Features.Catalog;
using BillingMadeEasy.Web.Features.Parties;

namespace BillingMadeEasy.Web.Features.Sales;

public sealed class InvoiceForm
{
    public long BusinessProfileId { get; set; }
    public long? PartyId { get; set; }
    public long? PartyLocationId { get; set; }
    [StringLength(200)] public string? BuyerName { get; set; }
    public string? BuyerGstin { get; set; }
    [StringLength(500)] public string? BuyerAddress { get; set; }
    public string? BuyerStateCode { get; set; }
    [StringLength(20)] public string? BuyerPhone { get; set; }
    [EmailAddress(ErrorMessage = "That email address doesn't look right."), StringLength(150)] public string? BuyerEmail { get; set; }
    public bool ShipElsewhere { get; set; }
    [StringLength(200)] public string? ShipToName { get; set; }
    [StringLength(500)] public string? ShipToAddress { get; set; }
    public string? ShipToStateCode { get; set; }
    public string? PlaceOfSupply { get; set; }
    [Required(ErrorMessage = "Enter the invoice date.")] public DateOnly? InvoiceDate { get; set; }
    public DateOnly? DueDate { get; set; }
    [StringLength(40)] public string? PoNumber { get; set; }
    public DateOnly? PoDate { get; set; }
    public bool IsReverseCharge { get; set; }
    [StringLength(1000)] public string? Notes { get; set; }
    [StringLength(2000)] public string? Terms { get; set; }
    public List<LineForm> Lines { get; set; } = [];
}

public sealed class LineForm
{
    public long? OfferingId { get; set; }
    [StringLength(300)] public string? Description { get; set; }
    [StringLength(10)] public string? HsnSacCode { get; set; }
    public decimal? Quantity { get; set; }
    [StringLength(20)] public string? UnitCode { get; set; }
    public decimal? Rate { get; set; }
    public bool RateIncludesTax { get; set; }
    public decimal? DiscountPercent { get; set; }
    public long? TaxRateId { get; set; }
    [StringLength(80)] public string? PriceSource { get; set; }

    public bool IsBlank => OfferingId is null && string.IsNullOrWhiteSpace(Description) && Rate is null or 0;
}

/// <summary>A built invoice: what to save, plus the problems found, keyed by form field.</summary>
public sealed record BuiltInvoice(object? SaveParameters, InvoiceTotals? Totals, byte DocumentType, IReadOnlyList<(string Field, string Message)> Problems)
{
    public bool Ok => Problems.Count == 0;
}

/// <summary>
/// Turns what was typed into an invoice the server stands behind. Tax rates come from the tax
/// table (valid on the invoice date), the buyer's GSTIN from their saved branch, pure-agent status
/// from the item, and every amount from <see cref="InvoiceMath"/>. Nothing the browser computed is
/// trusted.
/// </summary>
public sealed class InvoiceBuilder(BusinessStore business, PartyStore parties, CatalogStore catalog, IDb db)
{
    /// <summary>B2C inter-state invoices above this need the buyer's address and state (GSTR-1 B2CL).</summary>
    public const decimal B2CLargeThreshold = 100_000m;

    public async Task<IReadOnlyList<TaxOption>> TaxRatesOnAsync(long tenantId, DateOnly date, CancellationToken ct) =>
        await db.ListAsync<TaxOption>("dbo.usp_TaxRate_List", new { TenantId = tenantId, AsOnDate = date.ToDateTime(TimeOnly.MinValue) }, ct);

    public async Task<BuiltInvoice> BuildAsync(long tenantId, long invoiceId, InvoiceForm f, long userId, string? ip, CancellationToken ct)
    {
        var problems = new List<(string, string)>();
        void Problem(string field, string message) => problems.Add((field, message));

        var (profile, _) = await business.GetAsync(tenantId, f.BusinessProfileId == 0 ? null : f.BusinessProfileId, ct);
        if (profile is null || !profile.IsActive)
            return new(null, null, DocumentTypes.TaxInvoice, [("Form.BusinessProfileId", "Choose which of your businesses this invoice is from.")]);

        DateOnly date = f.InvoiceDate ?? DateOnly.FromDateTime(DateTime.Today);
        if (f.DueDate is { } due && due < date) Problem("Form.DueDate", "The due date can't be before the invoice date.");

        // ── Buyer: a saved customer's details come from their record, not from the form ──
        string? buyerName = Clean(f.BuyerName), buyerGstin = null, buyerState = Clean(f.BuyerStateCode);
        string? buyerAddress = Clean(f.BuyerAddress), buyerPhone = Clean(f.BuyerPhone), buyerEmail = Clean(f.BuyerEmail);
        long? locationId = null;
        if (f.PartyId is { } partyId)
        {
            var party = await parties.GetAsync(tenantId, partyId, ct);
            if (party is null) Problem("Form.PartyId", "That customer no longer exists.");
            else
            {
                buyerName = party.Party.LegalName;
                var location = party.Locations.FirstOrDefault(l => l.PartyLocationId == f.PartyLocationId)
                               ?? party.Locations.FirstOrDefault(l => l.IsDefault) ?? party.Locations.FirstOrDefault();
                if (location is not null)
                {
                    locationId = location.PartyLocationId;
                    buyerGstin = location.Gstin;
                    // A GSTIN's first two digits are the state it is registered in: that is the buyer's state.
                    buyerState = (Gstin.IsValid(location.Gstin) ? Gstin.StateCode(location.Gstin!) : null) ?? location.StateCode ?? buyerState;
                }
                buyerState ??= party.Addresses.FirstOrDefault(a => a.IsDefault)?.StateCode;
                buyerPhone ??= party.Party.Phone;
                buyerEmail ??= party.Party.Email;
                if (party.Party.Status != PartyCodes.StatusActive || !party.Party.IsActive)
                    Problem("Form.PartyId", $"{party.Party.DisplayName} is on hold or closed. Make them active on their page before invoicing.");
            }
        }
        else
        {
            buyerGstin = string.IsNullOrWhiteSpace(f.BuyerGstin) ? null : Gstin.Normalize(f.BuyerGstin);
            if (buyerGstin is not null)
            {
                if (Gstin.Check(buyerGstin) != GstinCheck.Valid) Problem("Form.BuyerGstin", "That isn't a valid GSTIN. Check each character.");
                else buyerState = Gstin.StateCode(buyerGstin);
            }
        }
        if (string.IsNullOrWhiteSpace(buyerName) || buyerName.Length < 2) Problem("Form.PartyId", "Choose a customer, or type a name for a walk-in customer.");

        // ── Place of supply: where goods are delivered, or where the buyer is ──
        string? shipState = f.ShipElsewhere ? Clean(f.ShipToStateCode) : null;
        string? place = Clean(f.PlaceOfSupply) ?? shipState ?? buyerState ?? profile.StateCode;
        bool inter = InvoiceMath.IsInterState(profile.StateCode, place);
        if (profile.StateCode is null) Problem("", "Set your business's state under Your business first: it decides CGST + SGST or IGST.");

        // ── Lines ──
        var rates = (await TaxRatesOnAsync(tenantId, date, ct)).ToDictionary(r => r.TaxRateId);
        var offerings = new Dictionary<long, Offering?>();
        var lines = new List<(LineForm Form, LineInput Input, decimal RatePercent, Offering? Item)>();
        for (int i = 0; i < f.Lines.Count; i++)
        {
            var l = f.Lines[i];
            if (l.IsBlank) continue;
            string key = $"Form.Lines[{i}]";
            Offering? item = null;
            if (l.OfferingId is { } oid)
            {
                if (!offerings.TryGetValue(oid, out item)) offerings[oid] = item = await catalog.GetAsync(tenantId, oid, ct);
                if (item is null) { Problem($"{key}.Description", "This item no longer exists."); continue; }
            }
            if (string.IsNullOrWhiteSpace(l.Description)) Problem($"{key}.Description", "Describe what's being sold.");
            if (l.Quantity is not > 0) Problem($"{key}.Quantity", "Enter a quantity.");
            if (l.Rate is null or < 0) Problem($"{key}.Rate", "Enter a rate.");
            if (l.DiscountPercent is < 0 or > 100) Problem($"{key}.DiscountPercent", "Between 0 and 100%.");

            bool pureAgent = item?.IsPureAgent ?? false;
            decimal ratePercent = 0;
            if (!pureAgent && !profile.IsComposition)
            {
                if (l.TaxRateId is { } tid)
                {
                    if (rates.TryGetValue(tid, out var rate)) ratePercent = rate.RatePercent;
                    else Problem($"{key}.TaxRateId", $"That GST rate doesn't apply on {date:d MMM yyyy}. Choose a current one.");
                }
                else Problem($"{key}.TaxRateId", "Choose the GST rate (Nil or Exempt if none applies).");
            }

            string? hsn = Hsn.Normalize(l.HsnSacCode);
            if (Hsn.Problem(hsn, item?.OfferingType == OfferingType.Service || (hsn?.StartsWith("99") ?? false)) is { } hsnProblem)
                Problem($"{key}.HsnSacCode", hsnProblem);

            lines.Add((l, new LineInput(l.Quantity ?? 0, l.Rate ?? 0, l.RateIncludesTax, l.DiscountPercent ?? 0, ratePercent, pureAgent, hsn), ratePercent, item));
        }
        if (lines.Count == 0) Problem("Form.Lines", "Add at least one line.");
        if (problems.Count > 0) return new(null, null, DocumentTypes.TaxInvoice, problems);

        var totals = InvoiceMath.Compute(lines.Select(x => x.Input), inter, profile.RoundOffTotal, noTax: profile.IsComposition);

        // A composition dealer, or a sale that is entirely exempt, issues a bill of supply.
        bool allUntaxed = lines.Where(x => !x.Input.IsPureAgent).All(x => x.RatePercent == 0);
        byte docType = profile.IsComposition || allUntaxed ? DocumentTypes.BillOfSupply : DocumentTypes.TaxInvoice;

        if (buyerGstin is null && inter && totals.GrandTotal > B2CLargeThreshold && (buyerAddress is null || buyerState is null))
            Problem("Form.BuyerAddress", $"Inter-state sales over {B2CLargeThreshold:N0} to an unregistered buyer need their address and state on the invoice.");
        if (problems.Count > 0) return new(null, totals, docType, problems);

        var lineRows = lines.Select((x, n) =>
        {
            var a = totals.Lines[n];
            return new
            {
                LineNumber = n + 1,
                x.Form.OfferingId,
                Description = x.Form.Description!.Trim(),
                Details = (string?)null,
                HsnSacCode = x.Input.HsnSacCode,
                Quantity = x.Input.Quantity,
                UnitCode = Clean(x.Form.UnitCode),
                UqcCode = (string?)null,
                Rate = x.Input.Rate,
                x.Input.RateIncludesTax,
                x.Input.DiscountPercent,
                GrossAmount = a.Gross,
                DiscountAmount = a.Discount,
                TaxableValue = a.Taxable,
                TaxRateId = a.IsPureAgent || profile.IsComposition ? null : x.Form.TaxRateId,
                TaxRatePercent = a.TaxRatePercent,
                CgstAmount = a.Cgst,
                SgstAmount = a.Sgst,
                IgstAmount = a.Igst,
                LineTotal = a.Total,
                IsPureAgent = a.IsPureAgent,
                PriceSource = Clean(x.Form.PriceSource) ?? "Entered",
            };
        }).ToList();

        var parameters = new
        {
            TenantId = tenantId,
            SalesInvoiceId = invoiceId,
            BusinessProfileId = profile.BusinessProfileId,
            DocumentType = docType,
            InvoiceDate = date.ToDateTime(TimeOnly.MinValue),
            DueDate = f.DueDate?.ToDateTime(TimeOnly.MinValue),
            f.PartyId,
            PartyLocationId = locationId,
            BuyerName = buyerName,
            BuyerGstin = buyerGstin,
            BuyerAddress = buyerAddress,
            BuyerStateCode = buyerState,
            BuyerPhone = buyerPhone,
            BuyerEmail = buyerEmail,
            ShipToName = f.ShipElsewhere ? Clean(f.ShipToName) : null,
            ShipToAddress = f.ShipElsewhere ? Clean(f.ShipToAddress) : null,
            ShipToStateCode = shipState,
            PlaceOfSupply = place,
            IsInterState = inter,
            f.IsReverseCharge,
            IsComposition = profile.IsComposition,
            RoundOffTotal = profile.RoundOffTotal,
            PoNumber = Clean(f.PoNumber),
            PoDate = f.PoDate?.ToDateTime(TimeOnly.MinValue),
            Notes = Clean(f.Notes),
            Terms = Clean(f.Terms),
            GrossTotal = totals.Gross,
            DiscountTotal = totals.Discount,
            TaxableTotal = totals.Taxable,
            CgstTotal = totals.Cgst,
            SgstTotal = totals.Sgst,
            IgstTotal = totals.Igst,
            ReimbursementTotal = totals.Reimbursements,
            totals.RoundOff,
            totals.GrandTotal,
            Lines = JsonSerializer.Serialize(lineRows),
            ActionByUserId = userId,
            IpAddress = ip,
        };
        return new(parameters, totals, docType, []);
    }

    private static string? Clean(string? s) => string.IsNullOrWhiteSpace(s) ? null : s.Trim();
}
