using System.ComponentModel.DataAnnotations;
using System.Text.Json;
using BillingMadeEasy.Core.Billing;
using BillingMadeEasy.Web.Features.Business;
using BillingMadeEasy.Web.Features.Sales;
using BillingMadeEasy.Web.Infrastructure.Formatting;
using BillingMadeEasy.Web.Infrastructure.Pages;
using Microsoft.AspNetCore.Mvc;

namespace BillingMadeEasy.Web.Pages.Sales.CreditNotes;

/// <summary>
/// A credit note always starts from the invoice it corrects: GST needs that link, and it lets every
/// figure be checked against what was actually billed. The page shows what each line can still give
/// back; the server works out every amount again with <see cref="CreditNoteMath"/>.
/// </summary>
public sealed class NewModel(InvoiceStore invoices, CreditNoteStore notes, BusinessStore business) : TenantPageModel
{
    public sealed class NoteForm
    {
        [Required(ErrorMessage = "Enter the credit note date.")] public DateOnly? NoteDate { get; set; }
        public byte ReasonCode { get; set; } = CreditNoteReasons.SalesReturn;
        [StringLength(300)] public string? ReasonText { get; set; }
        [StringLength(1000)] public string? Notes { get; set; }
        public List<LineForm> Lines { get; set; } = [];
    }

    public sealed class LineForm
    {
        public long SalesInvoiceLineId { get; set; }
        [Range(0, 999_999_999, ErrorMessage = "Can't be negative.")] public decimal? Quantity { get; set; }
        [Range(0, 999_999_999_999, ErrorMessage = "Can't be negative.")] public decimal? Taxable { get; set; }
    }

    [BindProperty(SupportsGet = true)] public long InvoiceId { get; set; }

    public Invoice Invoice { get; private set; } = null!;
    public IReadOnlyList<CreditableInvoiceLine> Lines { get; private set; } = [];
    public IReadOnlyList<InvoiceCreditNote> Earlier { get; private set; } = [];
    public NoteForm Form { get; private set; } = new();
    public DateOnly Today => DateOnly.FromDateTime(When.TodayIst());
    public DateOnly LastDate => CreditNoteRules.LastDate(DateOnly.FromDateTime(Invoice.InvoiceDate));
    public bool PastDeadline => Today > LastDate;
    public decimal CreditedBefore => Earlier.Where(n => n.IsActive).Sum(n => n.GrandTotal);
    public bool NothingLeft => Lines.All(l => l.TaxableLeft <= 0);

    public async Task<IActionResult> OnGetAsync(CancellationToken ct)
    {
        if (await LoadAsync(ct) is { } stop) return stop;
        Form = new NoteForm
        {
            NoteDate = PastDeadline ? LastDate : Today,
            Lines = Lines.Select(l => new LineForm { SalesInvoiceLineId = l.SalesInvoiceLineId }).ToList(),
        };
        return Page();
    }

    public async Task<IActionResult> OnPostAsync([FromForm(Name = "Form")] NoteForm form, CancellationToken ct)
    {
        if (await LoadAsync(ct) is { } stop) return stop;
        Form = form;
        var typed = form.Lines.Where(l => l.SalesInvoiceLineId != 0).GroupBy(l => l.SalesInvoiceLineId).ToDictionary(g => g.Key, g => g.First());
        // Keep one form row per invoice line, in invoice order, so errors land on the right row.
        Form.Lines = Lines.Select(l => typed.TryGetValue(l.SalesInvoiceLineId, out var t) ? t : new LineForm { SalesInvoiceLineId = l.SalesInvoiceLineId }).ToList();

        if (!CreditNoteReasons.IsValid(form.ReasonCode)) ModelState.AddModelError("Form.ReasonCode", "Choose why the credit note is being issued.");
        if (form.ReasonCode == CreditNoteReasons.Others && string.IsNullOrWhiteSpace(form.ReasonText))
            ModelState.AddModelError("Form.ReasonText", "Describe the reason. It prints on the credit note.");

        var computed = new List<CreditLineAmounts>();
        bool settlesEverything = true;
        for (int i = 0; i < Lines.Count; i++)
        {
            var original = Lines[i];
            var entry = Form.Lines[i];
            decimal qty = entry.Quantity ?? 0;
            if (qty == 0 && entry.Taxable is null or 0)
            {
                if (original.TaxableLeft > 0) settlesEverything = false;
                continue;
            }
            var (line, problem) = CreditNoteMath.Line(original.ToMath(), new CreditRequest(original.SalesInvoiceLineId, qty, entry.Taxable is 0 ? null : entry.Taxable), Invoice.IsInterState);
            if (problem is not null) { ModelState.AddModelError($"Form.Lines[{i}].Taxable", problem + "."); continue; }
            if (line is null) continue;
            computed.Add(line);
            if (original.TaxableLeft - line.Taxable > 0) settlesEverything = false;
        }
        if (computed.Count == 0 && ModelState.IsValid) ModelState.AddModelError("", "Enter the quantity returned or the value being credited on at least one line.");
        if (form.ReasonCode == CreditNoteReasons.SalesReturn && computed.Count > 0 && computed.All(c => c.Quantity == 0))
            ModelState.AddModelError("", "Goods returned: enter the quantity that came back. For a price reduction choose “Discount after sale” or “Charged too much”.");

        if (!ModelState.IsValid) return Page();

        var totals = CreditNoteMath.Totals(computed, Invoice.RoundOffTotal, Invoice.GrandTotal, CreditedBefore, settlesEverything);
        var (profile, accounts) = await business.GetAsync(TenantId, Invoice.BusinessProfileId, ct);
        if (profile is null) return NotFound();

        var result = await notes.IssueAsync(new
        {
            TenantId,
            SalesInvoiceId = InvoiceId,
            NoteDate = form.NoteDate!.Value.ToDateTime(TimeOnly.MinValue),
            form.ReasonCode,
            ReasonText = string.IsNullOrWhiteSpace(form.ReasonText) ? null : form.ReasonText.Trim(),
            Notes = string.IsNullOrWhiteSpace(form.Notes) ? null : form.Notes.Trim(),
            TaxableTotal = totals.Taxable,
            CgstTotal = totals.Cgst,
            SgstTotal = totals.Sgst,
            IgstTotal = totals.Igst,
            ReimbursementTotal = totals.Reimbursements,
            totals.RoundOff,
            totals.GrandTotal,
            Lines = JsonSerializer.Serialize(totals.Lines.Select(l => new
            {
                l.SalesInvoiceLineId, l.Quantity, TaxableValue = l.Taxable, l.TaxRatePercent,
                CgstAmount = l.Cgst, SgstAmount = l.Sgst, IgstAmount = l.Igst, LineTotal = l.Total, l.IsPureAgent,
            })),
            SellerSnapshot = Seller.From(profile, accounts).ToJson(),
            Today = Today.ToDateTime(TimeOnly.MinValue),
            ActionByUserId = UserId,
            IpAddress,
        }, ct);

        if (result.Succeeded)
        {
            Flash = $"Issued {result.NoteNumber}."
                + (result.AppliedToInvoice > 0 ? $" {Money.Inr(result.AppliedToInvoice)} comes off {Invoice.InvoiceNumber}." : "")
                + (result.CreditLeft > 0 ? $" {Money.Inr(result.CreditLeft)} is the customer's credit: apply it to another invoice or refund it." : "");
            return Redirect($"/Sales/CreditNotes/View/{result.CreditNoteId}");
        }
        ModelState.AddModelError(result.FieldName is null ? "" : "Form." + result.FieldName, result.ResultMessage + ".");
        // Someone else may have credited these lines meanwhile: show what is left now.
        await LoadAsync(ct);
        return Page();
    }

    private async Task<IActionResult?> LoadAsync(CancellationToken ct)
    {
        var (invoice, _) = await invoices.GetAsync(TenantId, InvoiceId, ct);
        if (invoice is null) return NotFound();
        if (!invoice.IsIssued)
        {
            Flash = invoice.IsDraft ? "This invoice is still a draft: edit it instead of raising a credit note." : "This invoice is cancelled, so there is nothing to credit.";
            return Redirect($"/Sales/Invoices/View/{InvoiceId}");
        }
        Invoice = invoice;
        (Lines, Earlier) = await notes.CreditableAsync(TenantId, InvoiceId, ct);
        return null;
    }
}
