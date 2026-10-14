using BillingMadeEasy.Core;
using BillingMadeEasy.Data;

namespace BillingMadeEasy.Web.Features.Sales;

public static class CreditNoteStatus
{
    public const byte Issued = 2;
    public const byte Cancelled = 3;
}

public sealed class CreditNoteRow
{
    public long CreditNoteId { get; init; }
    public string NoteNumber { get; init; } = "";
    public DateTime NoteDate { get; init; }
    public long? PartyId { get; init; }
    public string BuyerName { get; init; } = "";
    public string? BuyerGstin { get; init; }
    public byte ReasonCode { get; init; }
    public byte Status { get; init; }
    public decimal TaxableTotal { get; init; }
    public decimal Tax { get; init; }
    public decimal GrandTotal { get; init; }
    public decimal CreditLeft { get; init; }
    public long SalesInvoiceId { get; init; }
    public string? InvoiceNumber { get; init; }
    public int Total { get; init; }
}

public sealed class CreditNoteSummary
{
    public decimal CreditedThisMonth { get; init; }
    public decimal TaxThisMonth { get; init; }
    public int NotesThisMonth { get; init; }
    public decimal OpenCredit { get; init; }
}

public sealed record CreditNotePage(IReadOnlyList<CreditNoteRow> Rows, CreditNoteSummary Summary, int Total, int Page, int PageSize)
{
    public int Pages => Math.Max(1, (int)Math.Ceiling(Total / (double)PageSize));
}

public sealed class CreditNote
{
    public long CreditNoteId { get; init; }
    public long BusinessProfileId { get; init; }
    public long SalesInvoiceId { get; init; }
    public long? PartyId { get; init; }
    public string NoteNumber { get; init; } = "";
    public DateTime NoteDate { get; init; }
    public byte ReasonCode { get; init; }
    public string? ReasonText { get; init; }
    public byte Status { get; init; }
    public string BuyerName { get; init; } = "";
    public string? BuyerGstin { get; init; }
    public string? BuyerAddress { get; init; }
    public string? BuyerStateCode { get; init; }
    public string? PlaceOfSupply { get; init; }
    public string? PlaceOfSupplyName { get; init; }
    public bool IsInterState { get; init; }
    public bool IsComposition { get; init; }
    public bool IsReverseCharge { get; init; }
    public decimal TaxableTotal { get; init; }
    public decimal CgstTotal { get; init; }
    public decimal SgstTotal { get; init; }
    public decimal IgstTotal { get; init; }
    public decimal ReimbursementTotal { get; init; }
    public decimal RoundOff { get; init; }
    public decimal GrandTotal { get; init; }
    public string? Notes { get; init; }
    public string? SellerSnapshot { get; init; }
    public DateTime CreatedAtUtc { get; init; }
    public string? CreatedByName { get; init; }
    public DateTime? CancelledAtUtc { get; init; }
    public string? CancelledByName { get; init; }
    public string? CancelReason { get; init; }
    public string InvoiceNumber { get; init; } = "";
    public DateTime InvoiceDate { get; init; }
    public decimal InvoiceTotal { get; init; }
    public byte InvoiceDocumentType { get; init; }
    public decimal Applied { get; init; }
    public decimal Refunded { get; init; }
    public decimal CreditLeft { get; init; }

    public bool IsCancelled => Status == CreditNoteStatus.Cancelled;
    public decimal TaxTotal => CgstTotal + SgstTotal + IgstTotal;
}

public sealed class CreditNoteLine
{
    public long CreditNoteLineId { get; init; }
    public short LineNumber { get; init; }
    public long SalesInvoiceLineId { get; init; }
    public string Description { get; init; } = "";
    public string? HsnSacCode { get; init; }
    public decimal Quantity { get; init; }
    public string? UnitCode { get; init; }
    public decimal TaxableValue { get; init; }
    public decimal TaxRatePercent { get; init; }
    public decimal CgstAmount { get; init; }
    public decimal SgstAmount { get; init; }
    public decimal IgstAmount { get; init; }
    public decimal LineTotal { get; init; }
    public bool IsPureAgent { get; init; }
}

public sealed class CreditNoteAllocation
{
    public long CreditNoteAllocationId { get; init; }
    public long SalesInvoiceId { get; init; }
    public string? InvoiceNumber { get; init; }
    public DateTime InvoiceDate { get; init; }
    public decimal Amount { get; init; }
    public bool IsActive { get; init; }
}

public sealed class CreditNoteRefund
{
    public long CreditNoteRefundId { get; init; }
    public DateTime RefundDate { get; init; }
    public decimal Amount { get; init; }
    public byte Mode { get; init; }
    public string? Reference { get; init; }
    public string? Notes { get; init; }
    public bool IsActive { get; init; }
    public string? UndoReason { get; init; }
    public string? BankName { get; init; }
    public string? BankAccountNumber { get; init; }
}

public sealed record CreditNoteDetail(CreditNote Note, IReadOnlyList<CreditNoteLine> Lines,
    IReadOnlyList<CreditNoteAllocation> Allocations, IReadOnlyList<CreditNoteRefund> Refunds);

/// <summary>An invoice line with what earlier credit notes already took back.</summary>
public sealed class CreditableInvoiceLine
{
    public long SalesInvoiceLineId { get; init; }
    public short LineNumber { get; init; }
    public string Description { get; init; } = "";
    public string? HsnSacCode { get; init; }
    public decimal Quantity { get; init; }
    public string? UnitCode { get; init; }
    public decimal Rate { get; init; }
    public decimal TaxableValue { get; init; }
    public decimal TaxRatePercent { get; init; }
    public decimal CgstAmount { get; init; }
    public decimal SgstAmount { get; init; }
    public decimal IgstAmount { get; init; }
    public decimal LineTotal { get; init; }
    public bool IsPureAgent { get; init; }
    public decimal CreditedQuantity { get; init; }
    public decimal CreditedTaxable { get; init; }
    public decimal CreditedCgst { get; init; }
    public decimal CreditedSgst { get; init; }
    public decimal CreditedIgst { get; init; }

    public decimal QuantityLeft => Quantity - CreditedQuantity;
    public decimal TaxableLeft => TaxableValue - CreditedTaxable;

    public Core.Billing.CreditableLine ToMath() => new(SalesInvoiceLineId, Quantity, TaxableValue, TaxRatePercent,
        CgstAmount, SgstAmount, IgstAmount, IsPureAgent, CreditedQuantity, CreditedTaxable, CreditedCgst, CreditedSgst, CreditedIgst);
}

/// <summary>A credit note against an invoice, for the invoice's history.</summary>
public sealed class InvoiceCreditNote
{
    public long CreditNoteId { get; init; }
    public string NoteNumber { get; init; } = "";
    public DateTime NoteDate { get; init; }
    public byte ReasonCode { get; init; }
    public string? ReasonText { get; init; }
    public decimal GrandTotal { get; init; }
    public byte Status { get; init; }
    public string? CancelReason { get; init; }
    public decimal CreditLeft { get; init; }

    public bool IsActive => Status == CreditNoteStatus.Issued;
}

public sealed class OpenCredit
{
    public long CreditNoteId { get; init; }
    public string NoteNumber { get; init; } = "";
    public DateTime NoteDate { get; init; }
    public decimal GrandTotal { get; init; }
    public decimal CreditLeft { get; init; }
}

public sealed class CreditNoteIssueResult : ProcResult
{
    public string? FieldName { get; init; }
    public long CreditNoteId { get; init; }
    public string? NoteNumber { get; init; }
    public decimal AppliedToInvoice { get; init; }
    public decimal CreditLeft { get; init; }
}

public sealed class RefundUndoResult : ProcResult
{
    public long? CreditNoteId { get; init; }
}

public sealed class CreditNoteStore(IDb db)
{
    private static DateTime D(DateOnly d) => d.ToDateTime(TimeOnly.MinValue);

    public Task<CreditNotePage> ListAsync(long tenantId, string view, string? search, long? partyId, DateOnly today, int page, int pageSize, CancellationToken ct) =>
        db.MultipleAsync("dbo.usp_CreditNote_List",
            new { TenantId = tenantId, View = view, Search = search, PartyId = partyId, Today = D(today), Page = page, PageSize = pageSize },
            async grid =>
            {
                var rows = (await grid.ReadAsync<CreditNoteRow>()).ToList();
                var summary = await grid.ReadSingleAsync<CreditNoteSummary>();
                return new CreditNotePage(rows, summary, rows.FirstOrDefault()?.Total ?? 0, page, pageSize);
            }, ct);

    public Task<CreditNoteDetail?> GetAsync(long tenantId, long id, CancellationToken ct) =>
        db.MultipleAsync("dbo.usp_CreditNote_Get", new { TenantId = tenantId, CreditNoteId = id }, async grid =>
        {
            var note = await grid.ReadSingleOrDefaultAsync<CreditNote>();
            IReadOnlyList<CreditNoteLine> lines = (await grid.ReadAsync<CreditNoteLine>()).ToList();
            IReadOnlyList<CreditNoteAllocation> allocations = (await grid.ReadAsync<CreditNoteAllocation>()).ToList();
            IReadOnlyList<CreditNoteRefund> refunds = (await grid.ReadAsync<CreditNoteRefund>()).ToList();
            return note is null ? null : new CreditNoteDetail(note, lines, allocations, refunds);
        }, ct);

    public Task<(IReadOnlyList<CreditableInvoiceLine> Lines, IReadOnlyList<InvoiceCreditNote> Notes)> CreditableAsync(long tenantId, long invoiceId, CancellationToken ct) =>
        db.MultipleAsync("dbo.usp_CreditNote_Creditable", new { TenantId = tenantId, SalesInvoiceId = invoiceId }, async grid =>
        {
            IReadOnlyList<CreditableInvoiceLine> lines = (await grid.ReadAsync<CreditableInvoiceLine>()).ToList();
            IReadOnlyList<InvoiceCreditNote> notes = (await grid.ReadAsync<InvoiceCreditNote>()).ToList();
            return (lines, notes);
        }, ct);

    public Task<IReadOnlyList<OpenCredit>> OpenForPartyAsync(long tenantId, long partyId, CancellationToken ct) =>
        db.ListAsync<OpenCredit>("dbo.usp_CreditNote_OpenForParty", new { TenantId = tenantId, PartyId = partyId }, ct);

    public Task<CreditNoteIssueResult> IssueAsync(object parameters, CancellationToken ct) =>
        db.ResultAsync<CreditNoteIssueResult>("dbo.usp_CreditNote_Issue", parameters, ct);

    public Task<ProcResult> ApplyAsync(long tenantId, long id, string allocations, long userId, string? ip, CancellationToken ct) =>
        db.ResultAsync<ProcResult>("dbo.usp_CreditNote_Apply",
            new { TenantId = tenantId, CreditNoteId = id, Allocations = allocations, ActionByUserId = userId, IpAddress = ip }, ct);

    public Task<ProcResult> RefundAsync(object parameters, CancellationToken ct) =>
        db.ResultAsync<ProcResult>("dbo.usp_CreditNote_Refund", parameters, ct);

    public Task<RefundUndoResult> UndoRefundAsync(long tenantId, long refundId, string? reason, long userId, string? ip, CancellationToken ct) =>
        db.ResultAsync<RefundUndoResult>("dbo.usp_CreditNote_RefundUndo",
            new { TenantId = tenantId, CreditNoteRefundId = refundId, Reason = reason, ActionByUserId = userId, IpAddress = ip }, ct);

    public Task<ProcResult> CancelAsync(long tenantId, long id, string? reason, long userId, string? ip, CancellationToken ct) =>
        db.ResultAsync<ProcResult>("dbo.usp_CreditNote_Cancel",
            new { TenantId = tenantId, CreditNoteId = id, Reason = reason, ActionByUserId = userId, IpAddress = ip }, ct);
}
