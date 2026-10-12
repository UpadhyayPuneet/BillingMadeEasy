using BillingMadeEasy.Core;
using BillingMadeEasy.Data;

namespace BillingMadeEasy.Web.Features.Sales;

public static class PaymentStatus
{
    public const byte Recorded = 1;
    public const byte Reversed = 2;
}

public sealed class PaymentRow
{
    public long PaymentId { get; init; }
    public string ReceiptNumber { get; init; } = "";
    public DateTime PaymentDate { get; init; }
    public long? PartyId { get; init; }
    public string PayerName { get; init; } = "";
    public decimal Amount { get; init; }
    public decimal TdsAmount { get; init; }
    public byte Mode { get; init; }
    public string? Reference { get; init; }
    public byte Status { get; init; }
    public decimal Unapplied { get; init; }
    public string? Invoices { get; init; }
    public int Total { get; init; }
}

public sealed class PaymentSummary
{
    public decimal ReceivedThisMonth { get; init; }
    public decimal TdsThisMonth { get; init; }
    public decimal ReceivedToday { get; init; }
    public decimal CashThisMonth { get; init; }
    public decimal Advances { get; init; }
}

public sealed record PaymentPage(IReadOnlyList<PaymentRow> Rows, PaymentSummary Summary, int Total, int Page, int PageSize)
{
    public int Pages => Math.Max(1, (int)Math.Ceiling(Total / (double)PageSize));
}

public sealed class Payment
{
    public long PaymentId { get; init; }
    public long BusinessProfileId { get; init; }
    public long? PartyId { get; init; }
    public string PayerName { get; init; } = "";
    public string ReceiptNumber { get; init; } = "";
    public DateTime PaymentDate { get; init; }
    public decimal Amount { get; init; }
    public decimal TdsAmount { get; init; }
    public byte Mode { get; init; }
    public string? Reference { get; init; }
    public DateTime? InstrumentDate { get; init; }
    public long? BankAccountId { get; init; }
    public string? BankName { get; init; }
    public string? BankAccountNumber { get; init; }
    public string? Notes { get; init; }
    public byte Status { get; init; }
    public DateTime? ReversedAtUtc { get; init; }
    public string? ReversedByName { get; init; }
    public string? ReverseReason { get; init; }
    public DateTime CreatedAtUtc { get; init; }
    public string? CreatedByName { get; init; }
    public decimal Applied { get; init; }
    public decimal Unapplied { get; init; }

    public bool IsReversed => Status == PaymentStatus.Reversed;
}

public sealed class PaymentLine
{
    public long PaymentAllocationId { get; init; }
    public long SalesInvoiceId { get; init; }
    public string? InvoiceNumber { get; init; }
    public DateTime InvoiceDate { get; init; }
    public decimal GrandTotal { get; init; }
    public decimal Amount { get; init; }
    public decimal TdsAmount { get; init; }
    public bool IsActive { get; init; }
}

public sealed class OpenInvoice
{
    public long SalesInvoiceId { get; init; }
    public string InvoiceNumber { get; init; } = "";
    public DateTime InvoiceDate { get; init; }
    public DateTime? DueDate { get; init; }
    public decimal GrandTotal { get; init; }
    public decimal AmountPaid { get; init; }
    public decimal Balance { get; init; }
    public long BusinessProfileId { get; init; }
    public int? DaysOverdue { get; init; }
}

public sealed class Advance
{
    public long PaymentId { get; init; }
    public string ReceiptNumber { get; init; } = "";
    public DateTime PaymentDate { get; init; }
    public decimal Amount { get; init; }
    public decimal Unapplied { get; init; }
}

public sealed class InvoicePayment
{
    public long PaymentId { get; init; }
    public string ReceiptNumber { get; init; } = "";
    public DateTime PaymentDate { get; init; }
    public byte Mode { get; init; }
    public string? Reference { get; init; }
    public byte Status { get; init; }
    public string? ReverseReason { get; init; }
    public decimal Amount { get; init; }
    public decimal TdsAmount { get; init; }
    public bool IsActive { get; init; }
}

public sealed class PaymentResult : ProcResult
{
    public string? FieldName { get; init; }
    public long PaymentId { get; init; }
    public string? ReceiptNumber { get; init; }
}

public sealed class PaymentStore(IDb db)
{
    private static DateTime D(DateOnly d) => d.ToDateTime(TimeOnly.MinValue);

    public Task<PaymentPage> ListAsync(long tenantId, string view, string? search, long? partyId, DateOnly today, int page, int pageSize, CancellationToken ct) =>
        db.MultipleAsync("dbo.usp_Payment_List",
            new { TenantId = tenantId, View = view, Search = search, PartyId = partyId, Today = D(today), Page = page, PageSize = pageSize },
            async grid =>
            {
                var rows = (await grid.ReadAsync<PaymentRow>()).ToList();
                var summary = await grid.ReadSingleAsync<PaymentSummary>();
                return new PaymentPage(rows, summary, rows.FirstOrDefault()?.Total ?? 0, page, pageSize);
            }, ct);

    public Task<(Payment? Payment, IReadOnlyList<PaymentLine> Lines)> GetAsync(long tenantId, long id, CancellationToken ct) =>
        db.MultipleAsync("dbo.usp_Payment_Get", new { TenantId = tenantId, PaymentId = id }, async grid =>
        {
            var payment = await grid.ReadSingleOrDefaultAsync<Payment>();
            IReadOnlyList<PaymentLine> lines = (await grid.ReadAsync<PaymentLine>()).ToList();
            return (payment, lines);
        }, ct);

    public Task<(IReadOnlyList<OpenInvoice> Invoices, IReadOnlyList<Advance> Advances)> OpenAsync(long tenantId, long partyId, DateOnly today, CancellationToken ct) =>
        db.MultipleAsync("dbo.usp_Payment_OpenInvoices", new { TenantId = tenantId, PartyId = partyId, Today = D(today) }, async grid =>
        {
            IReadOnlyList<OpenInvoice> invoices = (await grid.ReadAsync<OpenInvoice>()).ToList();
            IReadOnlyList<Advance> advances = (await grid.ReadAsync<Advance>()).ToList();
            return (invoices, advances);
        }, ct);

    public Task<IReadOnlyList<InvoicePayment>> ForInvoiceAsync(long tenantId, long invoiceId, CancellationToken ct) =>
        db.ListAsync<InvoicePayment>("dbo.usp_Payment_ForInvoice", new { TenantId = tenantId, SalesInvoiceId = invoiceId }, ct);

    public Task<PaymentResult> RecordAsync(object parameters, CancellationToken ct) =>
        db.ResultAsync<PaymentResult>("dbo.usp_Payment_Record", parameters, ct);

    public Task<ProcResult> ApplyAsync(long tenantId, long paymentId, string allocations, long userId, string? ip, CancellationToken ct) =>
        db.ResultAsync<ProcResult>("dbo.usp_Payment_Apply",
            new { TenantId = tenantId, PaymentId = paymentId, Allocations = allocations, ActionByUserId = userId, IpAddress = ip }, ct);

    public Task<ProcResult> ReverseAsync(long tenantId, long paymentId, string? reason, long userId, string? ip, CancellationToken ct) =>
        db.ResultAsync<ProcResult>("dbo.usp_Payment_Reverse",
            new { TenantId = tenantId, PaymentId = paymentId, Reason = reason, ActionByUserId = userId, IpAddress = ip }, ct);
}
