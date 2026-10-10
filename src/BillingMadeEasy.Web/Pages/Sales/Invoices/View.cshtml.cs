using BillingMadeEasy.Core.Billing;
using BillingMadeEasy.Core.Modules;
using BillingMadeEasy.Web.Features.Business;
using BillingMadeEasy.Web.Features.Sales;
using BillingMadeEasy.Web.Infrastructure.Formatting;
using BillingMadeEasy.Web.Infrastructure.Modules;
using BillingMadeEasy.Web.Infrastructure.Pages;
using Microsoft.AspNetCore.Mvc;

namespace BillingMadeEasy.Web.Pages.Sales.Invoices;

public sealed class ViewModel(InvoiceStore invoices, BusinessStore business, EntitlementService entitlements) : TenantPageModel
{
    [BindProperty(SupportsGet = true)] public long Id { get; set; }

    public Invoice Invoice { get; private set; } = null!;
    public IReadOnlyList<InvoiceLine> Lines { get; private set; } = [];
    public Seller? Seller { get; private set; }
    public IReadOnlyList<TaxSummaryRow> TaxSummary { get; private set; } = [];
    public string? UpiQr { get; private set; }
    public string? CancelError { get; private set; }

    public bool CanIssue => Can("Sales.Invoice.Issue");
    public bool CanCancel => Can("Sales.Invoice.Cancel");
    public bool CanCreate => Can("Sales.Invoice.Create");

    public async Task<IActionResult> OnGetAsync(CancellationToken ct) => await LoadAsync(ct) ? Page() : NotFound();

    public async Task<IActionResult> OnPostIssueAsync(CancellationToken ct)
    {
        if (!CanIssue) return Forbid();
        if (!await LoadAsync(ct)) return NotFound();
        if (!Invoice.IsDraft) return Redirect($"/Sales/Invoices/View/{Id}");
        var (profile, accounts) = await business.GetAsync(TenantId, Invoice.BusinessProfileId, ct);
        if (profile is null) return NotFound();
        int? limit = (await entitlements.GetAsync(TenantId, ct)).Limit(Meters.InvoicesPerMonth);
        var result = await invoices.IssueAsync(TenantId, Id, Features.Sales.Seller.From(profile, accounts).ToJson(),
            DateOnly.FromDateTime(When.TodayIst()), limit, UserId, IpAddress, ct);
        Flash = result.Succeeded ? $"Issued {result.InvoiceNumber}." : result.ResultMessage + ".";
        return Redirect($"/Sales/Invoices/View/{Id}");
    }

    public async Task<IActionResult> OnPostCancelAsync(string? reason, CancellationToken ct)
    {
        if (!CanCancel) return Forbid();
        var result = await invoices.CancelAsync(TenantId, Id, reason?.Trim(), UserId, IpAddress, ct);
        if (result.Succeeded)
        {
            Flash = result.Discarded ? "Draft discarded." : "Cancelled. The number stays in the register, marked cancelled, and is never reused.";
            return Redirect(result.Discarded ? "/Sales/Invoices" : $"/Sales/Invoices/View/{Id}");
        }
        CancelError = result.ResultMessage + ".";
        return await LoadAsync(ct) ? Page() : NotFound();
    }

    private async Task<bool> LoadAsync(CancellationToken ct)
    {
        var (invoice, lines) = await invoices.GetAsync(TenantId, Id, ct);
        if (invoice is null) return false;
        Invoice = invoice;
        Lines = lines;

        // Issued: exactly what was printed then. Draft: today's details.
        Seller = Features.Sales.Seller.FromJson(invoice.SellerSnapshot);
        if (Seller is null)
        {
            var (profile, accounts) = await business.GetAsync(TenantId, invoice.BusinessProfileId, ct);
            if (profile is not null) Seller = Features.Sales.Seller.From(profile, accounts);
        }

        TaxSummary = lines.Where(l => !l.IsPureAgent)
            .GroupBy(l => (l.HsnSacCode, l.TaxRatePercent))
            .OrderBy(g => g.Key.HsnSacCode ?? "~").ThenBy(g => g.Key.TaxRatePercent)
            .Select(g => new TaxSummaryRow(g.Key.HsnSacCode, g.Key.TaxRatePercent, g.Sum(l => l.TaxableValue), g.Sum(l => l.CgstAmount), g.Sum(l => l.SgstAmount), g.Sum(l => l.IgstAmount)))
            .ToList();

        if (invoice.IsIssued && invoice.Balance > 0 && Seller?.Bank?.UpiId is { } upi)
            UpiQr = Features.Sales.UpiQr.DataUri(Features.Sales.UpiQr.Link(upi, Seller.LegalName, invoice.Balance, invoice.InvoiceNumber));
        return true;
    }
}
