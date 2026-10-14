using System.ComponentModel.DataAnnotations;
using System.Text.Json;
using BillingMadeEasy.Core.Billing;
using BillingMadeEasy.Web.Features.Business;
using BillingMadeEasy.Web.Features.Sales;
using BillingMadeEasy.Web.Infrastructure.Formatting;
using BillingMadeEasy.Web.Infrastructure.Pages;
using Microsoft.AspNetCore.Mvc;

namespace BillingMadeEasy.Web.Pages.Sales.CreditNotes;

public sealed class ViewModel(CreditNoteStore notes, PaymentStore payments, BusinessStore business) : TenantPageModel
{
    public sealed class ApplyForm
    {
        public long SalesInvoiceId { get; set; }
        public decimal? Amount { get; set; }
    }

    public sealed class RefundForm
    {
        [Required(ErrorMessage = "Enter the date it was paid back.")] public DateOnly? RefundDate { get; set; }
        [Required(ErrorMessage = "Enter the amount refunded.")] public decimal? Amount { get; set; }
        public byte Mode { get; set; } = PaymentModes.BankTransfer;
        [StringLength(60)] public string? Reference { get; set; }
        public long? BankAccountId { get; set; }
        [StringLength(500)] public string? Notes { get; set; }
    }

    [BindProperty(SupportsGet = true)] public long Id { get; set; }

    public CreditNote Note { get; private set; } = null!;
    public IReadOnlyList<CreditNoteLine> Lines { get; private set; } = [];
    public IReadOnlyList<CreditNoteAllocation> Allocations { get; private set; } = [];
    public IReadOnlyList<CreditNoteRefund> Refunds { get; private set; } = [];
    public IReadOnlyList<TaxSummaryRow> TaxSummary { get; private set; } = [];
    public IReadOnlyList<OpenInvoice> Open { get; private set; } = [];
    public IReadOnlyList<BankAccount> Accounts { get; private set; } = [];
    public Seller? Seller { get; private set; }
    public RefundForm Refund { get; private set; } = new();
    public string? Error { get; private set; }
    public string? OpenDialog { get; private set; }
    public DateOnly Today => DateOnly.FromDateTime(When.TodayIst());

    public bool CanManage => Can("Sales.CreditNote.Manage");

    public async Task<IActionResult> OnGetAsync(CancellationToken ct) => await LoadAsync(ct) ? Page() : NotFound();

    public async Task<IActionResult> OnPostApplyAsync([FromForm(Name = "Apply")] List<ApplyForm> apply, CancellationToken ct)
    {
        if (!CanManage) return Forbid();
        var rows = apply.Where(a => (a.Amount ?? 0) > 0).Select(a => new { a.SalesInvoiceId, Amount = a.Amount ?? 0 }).ToList();
        if (rows.Count == 0) { Flash = "Enter an amount against at least one invoice."; return Redirect($"/Sales/CreditNotes/View/{Id}#apply"); }
        var result = await notes.ApplyAsync(TenantId, Id, JsonSerializer.Serialize(rows), UserId, IpAddress, ct);
        Flash = result.Succeeded ? $"Applied {Money.Inr(rows.Sum(r => r.Amount))} to {rows.Count} {(rows.Count == 1 ? "invoice" : "invoices")}." : result.ResultMessage + ".";
        return Redirect($"/Sales/CreditNotes/View/{Id}");
    }

    public async Task<IActionResult> OnPostRefundAsync([FromForm(Name = "Refund")] RefundForm form, CancellationToken ct)
    {
        if (!CanManage) return Forbid();
        Refund = form;
        if (form.Mode is PaymentModes.BankTransfer or PaymentModes.Upi or PaymentModes.Cheque && string.IsNullOrWhiteSpace(form.Reference))
            ModelState.AddModelError("Refund.Reference", form.Mode == PaymentModes.Cheque ? "Enter the cheque number." : "Enter the UTR, so the refund can be traced.");
        if (ModelState.IsValid)
        {
            var result = await notes.RefundAsync(new
            {
                TenantId,
                CreditNoteId = Id,
                RefundDate = form.RefundDate!.Value.ToDateTime(TimeOnly.MinValue),
                form.Amount,
                form.Mode,
                Reference = string.IsNullOrWhiteSpace(form.Reference) ? null : form.Reference.Trim(),
                BankAccountId = form.Mode == PaymentModes.Cash ? null : form.BankAccountId,
                form.Notes,
                Today = Today.ToDateTime(TimeOnly.MinValue),
                ActionByUserId = UserId,
                IpAddress,
            }, ct);
            if (result.Succeeded)
            {
                Flash = $"Refund of {Money.Inr(form.Amount ?? 0)} recorded.";
                return Redirect($"/Sales/CreditNotes/View/{Id}");
            }
            Error = result.ResultMessage + ".";
        }
        OpenDialog = "refund";
        return await LoadAsync(ct) ? Page() : NotFound();
    }

    public async Task<IActionResult> OnPostUndoRefundAsync(long refundId, string? reason, CancellationToken ct)
    {
        if (!CanManage) return Forbid();
        var result = await notes.UndoRefundAsync(TenantId, refundId, reason?.Trim(), UserId, IpAddress, ct);
        if (result.Succeeded || result.CreditNoteId != Id)
        {
            Flash = result.Succeeded ? "Refund undone. The amount is the customer's credit again." : result.ResultMessage + ".";
            return Redirect($"/Sales/CreditNotes/View/{Id}");
        }
        Error = result.ResultMessage + ".";
        OpenDialog = "undo-" + refundId;
        return await LoadAsync(ct) ? Page() : NotFound();
    }

    public async Task<IActionResult> OnPostCancelAsync(string? reason, CancellationToken ct)
    {
        if (!CanManage) return Forbid();
        var result = await notes.CancelAsync(TenantId, Id, reason?.Trim(), UserId, IpAddress, ct);
        if (result.Succeeded)
        {
            Flash = "Cancelled. The invoices it settled owe again; the number stays in the register, marked cancelled.";
            return Redirect($"/Sales/CreditNotes/View/{Id}");
        }
        Error = result.ResultMessage + ".";
        OpenDialog = "cancel";
        return await LoadAsync(ct) ? Page() : NotFound();
    }

    private async Task<bool> LoadAsync(CancellationToken ct)
    {
        var detail = await notes.GetAsync(TenantId, Id, ct);
        if (detail is null) return false;
        (Note, Lines, Allocations, Refunds) = (detail.Note, detail.Lines, detail.Allocations, detail.Refunds);

        Seller = Features.Sales.Seller.FromJson(Note.SellerSnapshot);
        var (profile, accounts) = await business.GetAsync(TenantId, Note.BusinessProfileId, ct);
        Accounts = accounts;
        if (Seller is null && profile is not null) Seller = Features.Sales.Seller.From(profile, accounts);

        Refund.RefundDate ??= Today;
        Refund.Amount ??= Note.CreditLeft > 0 ? Note.CreditLeft : null;
        Refund.BankAccountId ??= accounts.FirstOrDefault(a => a.IsDefault)?.BankAccountId;

        TaxSummary = Lines.Where(l => !l.IsPureAgent)
            .GroupBy(l => (l.HsnSacCode, l.TaxRatePercent))
            .OrderBy(g => g.Key.HsnSacCode ?? "~").ThenBy(g => g.Key.TaxRatePercent)
            .Select(g => new TaxSummaryRow(g.Key.HsnSacCode, g.Key.TaxRatePercent, g.Sum(l => l.TaxableValue), g.Sum(l => l.CgstAmount), g.Sum(l => l.SgstAmount), g.Sum(l => l.IgstAmount)))
            .ToList();

        if (!Note.IsCancelled && Note.CreditLeft > 0 && Note.PartyId is long pid && CanManage)
            (Open, _) = await payments.OpenAsync(TenantId, pid, Today, ct);
        Open = Open.Where(o => o.BusinessProfileId == Note.BusinessProfileId).ToList();
        return true;
    }
}
