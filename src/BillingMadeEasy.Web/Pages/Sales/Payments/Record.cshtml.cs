using System.ComponentModel.DataAnnotations;
using System.Text.Json;
using BillingMadeEasy.Core.Billing;
using BillingMadeEasy.Core.Parties;
using BillingMadeEasy.Web.Features.Business;
using BillingMadeEasy.Web.Features.Parties;
using BillingMadeEasy.Web.Features.Sales;
using BillingMadeEasy.Web.Infrastructure.Formatting;
using BillingMadeEasy.Web.Infrastructure.Pages;
using Microsoft.AspNetCore.Mvc;

namespace BillingMadeEasy.Web.Pages.Sales.Payments;

public sealed class RecordModel(PaymentStore payments, PartyStore parties, BusinessStore business, InvoiceStore invoices, CreditNoteStore creditNotes) : TenantPageModel
{
    public sealed class PaymentForm
    {
        public long? PartyId { get; set; }
        [StringLength(200)] public string? PayerName { get; set; }
        [Required(ErrorMessage = "Enter the date it was received.")] public DateOnly? PaymentDate { get; set; }
        [Required(ErrorMessage = "Enter the amount received.")]
        [Range(0, 999_999_999_999, ErrorMessage = "Enter the amount received.")] public decimal? Amount { get; set; }
        public byte Mode { get; set; } = PaymentModes.BankTransfer;
        [StringLength(60)] public string? Reference { get; set; }
        public DateOnly? InstrumentDate { get; set; }
        public long? BankAccountId { get; set; }
        [StringLength(500)] public string? Notes { get; set; }
        public List<AllocationForm> Allocations { get; set; } = [];
    }

    public sealed class AllocationForm
    {
        public long SalesInvoiceId { get; set; }
        [Range(0, 999_999_999_999, ErrorMessage = "Can't be negative.")] public decimal? Amount { get; set; }
        [Range(0, 999_999_999_999, ErrorMessage = "Can't be negative.")] public decimal? TdsAmount { get; set; }
    }

    public PaymentForm Form { get; private set; } = new();
    public string? CustomerLabel { get; private set; }
    /// <summary>The invoice the payment was started from: it is settled first.</summary>
    [BindProperty(SupportsGet = true)] public long? InvoiceId { get; set; }
    public IReadOnlyList<OpenInvoice> Open { get; private set; } = [];
    public IReadOnlyList<Advance> Advances { get; private set; } = [];
    /// <summary>Credit notes with credit left: the customer may be paying less because of them.</summary>
    public IReadOnlyList<OpenCredit> Credits { get; private set; } = [];
    public IReadOnlyList<BankAccount> Accounts { get; private set; } = [];
    public DateOnly Today => DateOnly.FromDateTime(When.TodayIst());

    public async Task<IActionResult> OnGetAsync(long? partyId, CancellationToken ct)
    {
        Form = new PaymentForm { PaymentDate = Today };
        if (InvoiceId is long iid && await invoices.GetAsync(TenantId, iid, ct) is ({ } invoice, _))
        {
            // From an invoice: that customer, and the invoice's balance as the starting amount.
            partyId = invoice.PartyId;
            if (invoice.PartyId is null) { Form.PayerName = invoice.BuyerName; CustomerLabel = invoice.BuyerName; }
            if (invoice.Balance > 0) Form.Amount = invoice.Balance;
        }
        Form.PartyId = partyId;
        await LoadAsync(ct);
        return Page();
    }

    public async Task<IActionResult> OnPostAsync([FromForm(Name = "Form")] PaymentForm form, CancellationToken ct)
    {
        Form = form;
        if (form.PartyId is null && string.IsNullOrWhiteSpace(form.PayerName)) ModelState.AddModelError("Form.PartyId", "Choose the customer who paid.");
        if (form.Mode == PaymentModes.Cheque && string.IsNullOrWhiteSpace(form.Reference)) ModelState.AddModelError("Form.Reference", "Enter the cheque number.");
        if (form.Mode is PaymentModes.BankTransfer or PaymentModes.Upi && string.IsNullOrWhiteSpace(form.Reference))
            ModelState.AddModelError("Form.Reference", "Enter the UTR. It's how you'll find this payment in the bank statement.");

        var allocations = form.Allocations.Where(a => (a.Amount ?? 0) + (a.TdsAmount ?? 0) > 0).ToList();
        decimal applied = allocations.Sum(a => a.Amount ?? 0);
        if (form.Amount is decimal amount && applied > amount)
            ModelState.AddModelError("Form.Amount", $"The invoices take {Money.Inr(applied)}, more than the {Money.Inr(amount)} received.");

        if (ModelState.IsValid)
        {
            var result = await payments.RecordAsync(new
            {
                TenantId,
                BusinessProfileId = (long?)null,
                form.PartyId,
                PayerName = form.PartyId is null ? form.PayerName?.Trim() : null,
                PaymentDate = form.PaymentDate!.Value.ToDateTime(TimeOnly.MinValue),
                Amount = form.Amount ?? 0,
                form.Mode,
                Reference = string.IsNullOrWhiteSpace(form.Reference) ? null : form.Reference.Trim(),
                InstrumentDate = form.Mode == PaymentModes.Cheque ? form.InstrumentDate?.ToDateTime(TimeOnly.MinValue) : null,
                form.BankAccountId,
                form.Notes,
                Allocations = allocations.Count == 0 ? null : JsonSerializer.Serialize(allocations.Select(a => new
                {
                    a.SalesInvoiceId, Amount = a.Amount ?? 0, TdsAmount = a.TdsAmount ?? 0,
                })),
                Today = Today.ToDateTime(TimeOnly.MinValue),
                ActionByUserId = UserId,
                IpAddress,
            }, ct);
            if (result.Succeeded)
            {
                decimal advance = (form.Amount ?? 0) - applied;
                Flash = $"Recorded {result.ReceiptNumber}." + (advance > 0 ? $" {Money.Inr(advance)} is kept as an advance for future invoices." : "");
                return Redirect($"/Sales/Payments/View/{result.PaymentId}");
            }
            ModelState.AddModelError(result.FieldName is null ? "" : "Form." + result.FieldName, result.ResultMessage + ".");
        }

        await LoadAsync(ct);
        return Page();
    }

    /// <summary>A customer's open invoices and advances, for the allocation table.</summary>
    public async Task<IActionResult> OnGetOpenAsync(long partyId, CancellationToken ct)
    {
        var (open, advances) = await payments.OpenAsync(TenantId, partyId, Today, ct);
        var credits = Can("Sales.CreditNote.View") ? await creditNotes.OpenForPartyAsync(TenantId, partyId, ct) : [];
        return new JsonResult(new
        {
            invoices = open.Select(o => new
            {
                id = o.SalesInvoiceId, number = o.InvoiceNumber, date = o.InvoiceDate.ToString("d MMM yyyy"),
                due = o.DueDate?.ToString("d MMM"), overdue = o.DaysOverdue, total = o.GrandTotal, balance = o.Balance,
            }),
            advance = advances.Sum(a => a.Unapplied),
            advanceReceipts = advances.Select(a => a.ReceiptNumber),
            credit = credits.Sum(c => c.CreditLeft),
            creditNotes = credits.Select(c => c.NoteNumber),
        });
    }

    public async Task<IActionResult> OnGetCustomersAsync(string? q, CancellationToken ct)
    {
        var page = await parties.ListAsync(TenantId, PartyCodes.RoleCustomer, q, 1, 8, ct);
        return new JsonResult(page.Rows.Select(p => new { id = p.PartyId, name = p.DisplayName, city = p.PrimaryCity }));
    }

    private async Task LoadAsync(CancellationToken ct)
    {
        (_, Accounts) = await business.GetAsync(TenantId, null, ct);
        Form.BankAccountId ??= Accounts.FirstOrDefault(a => a.IsDefault)?.BankAccountId;
        if (Form.PartyId is long pid)
        {
            if (await parties.GetAsync(TenantId, pid, ct) is { } party) CustomerLabel = party.Party.DisplayName;
            (Open, Advances) = await payments.OpenAsync(TenantId, pid, Today, ct);
            if (Can("Sales.CreditNote.View")) Credits = await creditNotes.OpenForPartyAsync(TenantId, pid, ct);
        }
        else CustomerLabel ??= Form.PayerName;

        // One allocation row per open invoice, keeping what was typed.
        var typed = Form.Allocations.ToDictionary(a => a.SalesInvoiceId);
        Form.Allocations = Open.Select(o => typed.TryGetValue(o.SalesInvoiceId, out var t) ? t : new AllocationForm { SalesInvoiceId = o.SalesInvoiceId }).ToList();
    }
}
