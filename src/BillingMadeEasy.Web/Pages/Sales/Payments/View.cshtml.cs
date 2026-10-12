using System.Text.Json;
using BillingMadeEasy.Web.Features.Business;
using BillingMadeEasy.Web.Features.Sales;
using BillingMadeEasy.Web.Infrastructure.Formatting;
using BillingMadeEasy.Web.Infrastructure.Pages;
using Microsoft.AspNetCore.Mvc;

namespace BillingMadeEasy.Web.Pages.Sales.Payments;

public sealed class ViewModel(PaymentStore payments, BusinessStore business) : TenantPageModel
{
    public sealed class ApplyForm
    {
        public long SalesInvoiceId { get; set; }
        public decimal? Amount { get; set; }
        public decimal? TdsAmount { get; set; }
    }

    [BindProperty(SupportsGet = true)] public long Id { get; set; }

    public Payment Payment { get; private set; } = null!;
    public IReadOnlyList<PaymentLine> Lines { get; private set; } = [];
    public Seller? Seller { get; private set; }
    public IReadOnlyList<OpenInvoice> Open { get; private set; } = [];
    public string? Error { get; private set; }
    public string? OpenDialog { get; private set; }

    public bool CanReverse => Can("Sales.Payment.Delete");
    public bool CanApply => Can("Sales.Payment.Record");

    public async Task<IActionResult> OnGetAsync(CancellationToken ct) => await LoadAsync(ct) ? Page() : NotFound();

    public async Task<IActionResult> OnPostReverseAsync(string? reason, CancellationToken ct)
    {
        if (!CanReverse) return Forbid();
        var result = await payments.ReverseAsync(TenantId, Id, reason?.Trim(), UserId, IpAddress, ct);
        if (result.Succeeded)
        {
            Flash = "Reversed. The invoices it settled are open again; the receipt number stays in the register, marked reversed.";
            return Redirect($"/Sales/Payments/View/{Id}");
        }
        Error = result.ResultMessage + ".";
        OpenDialog = "reverse";
        return await LoadAsync(ct) ? Page() : NotFound();
    }

    public async Task<IActionResult> OnPostApplyAsync([FromForm(Name = "Apply")] List<ApplyForm> apply, CancellationToken ct)
    {
        if (!CanApply) return Forbid();
        var rows = apply.Where(a => (a.Amount ?? 0) + (a.TdsAmount ?? 0) > 0)
            .Select(a => new { a.SalesInvoiceId, Amount = a.Amount ?? 0, TdsAmount = a.TdsAmount ?? 0 }).ToList();
        if (rows.Count == 0) { Flash = "Enter an amount against at least one invoice."; return Redirect($"/Sales/Payments/View/{Id}#apply"); }
        var result = await payments.ApplyAsync(TenantId, Id, JsonSerializer.Serialize(rows), UserId, IpAddress, ct);
        Flash = result.Succeeded ? "Advance applied." : result.ResultMessage + ".";
        return Redirect($"/Sales/Payments/View/{Id}");
    }

    private async Task<bool> LoadAsync(CancellationToken ct)
    {
        var (payment, lines) = await payments.GetAsync(TenantId, Id, ct);
        if (payment is null) return false;
        Payment = payment;
        Lines = lines;
        var (profile, accounts) = await business.GetAsync(TenantId, payment.BusinessProfileId, ct);
        if (profile is not null) Seller = Features.Sales.Seller.From(profile, accounts);
        if (!payment.IsReversed && payment.Unapplied > 0 && payment.PartyId is long pid)
            (Open, _) = await payments.OpenAsync(TenantId, pid, DateOnly.FromDateTime(When.TodayIst()), ct);
        return true;
    }
}
