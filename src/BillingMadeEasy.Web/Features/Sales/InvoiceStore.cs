using BillingMadeEasy.Core;
using BillingMadeEasy.Data;

namespace BillingMadeEasy.Web.Features.Sales;

public static class InvoiceStatus
{
    public const byte Draft = 1;
    public const byte Issued = 2;
    public const byte Cancelled = 3;
}

public sealed class InvoiceRow
{
    public long SalesInvoiceId { get; init; }
    public byte Status { get; init; }
    public byte DocumentType { get; init; }
    public string? InvoiceNumber { get; init; }
    public DateTime InvoiceDate { get; init; }
    public DateTime? DueDate { get; init; }
    public long? PartyId { get; init; }
    public string BuyerName { get; init; } = "";
    public string? BuyerGstin { get; init; }
    public decimal GrandTotal { get; init; }
    public decimal AmountPaid { get; init; }
    public decimal Balance { get; init; }
    public bool IsOverdue { get; init; }
    public int? DaysOverdue { get; init; }
    public DateTime CreatedAtUtc { get; init; }
    public DateTime? UpdatedAtUtc { get; init; }
    public int Total { get; init; }
}

public sealed class InvoiceSummary
{
    public int? Drafts { get; init; }
    public decimal Outstanding { get; init; }
    public int? OutstandingCount { get; init; }
    public decimal Overdue { get; init; }
    public int? OverdueCount { get; init; }
    public decimal InvoicedThisMonth { get; init; }
}

public sealed record InvoicePage(IReadOnlyList<InvoiceRow> Rows, InvoiceSummary Summary, int Total, int Page, int PageSize)
{
    public int Pages => Math.Max(1, (int)Math.Ceiling(Total / (double)PageSize));
}

public sealed class Invoice
{
    public long SalesInvoiceId { get; init; }
    public Guid PublicId { get; init; }
    public long BusinessProfileId { get; init; }
    public string? ProfileName { get; init; }
    public byte DocumentType { get; init; }
    public byte Status { get; init; }
    public string? InvoiceNumber { get; init; }
    public DateTime InvoiceDate { get; init; }
    public DateTime? DueDate { get; init; }
    public long? PartyId { get; init; }
    public long? PartyLocationId { get; init; }
    public string BuyerName { get; init; } = "";
    public string? BuyerGstin { get; init; }
    public string? BuyerAddress { get; init; }
    public string? BuyerStateCode { get; init; }
    public string? BuyerPhone { get; init; }
    public string? BuyerEmail { get; init; }
    public string? ShipToName { get; init; }
    public string? ShipToAddress { get; init; }
    public string? ShipToStateCode { get; init; }
    public string? PlaceOfSupply { get; init; }
    public string? PlaceOfSupplyName { get; init; }
    public bool IsInterState { get; init; }
    public bool IsReverseCharge { get; init; }
    public bool IsComposition { get; init; }
    public bool RoundOffTotal { get; init; }
    public string? PoNumber { get; init; }
    public DateTime? PoDate { get; init; }
    public string? Notes { get; init; }
    public string? Terms { get; init; }
    public decimal GrossTotal { get; init; }
    public decimal DiscountTotal { get; init; }
    public decimal TaxableTotal { get; init; }
    public decimal CgstTotal { get; init; }
    public decimal SgstTotal { get; init; }
    public decimal IgstTotal { get; init; }
    public decimal ReimbursementTotal { get; init; }
    public decimal RoundOff { get; init; }
    public decimal GrandTotal { get; init; }
    public decimal AmountPaid { get; init; }
    public string? SellerSnapshot { get; init; }
    public DateTime? IssuedAtUtc { get; init; }
    public string? IssuedByName { get; init; }
    public DateTime? CancelledAtUtc { get; init; }
    public string? CancelledByName { get; init; }
    public string? CancelReason { get; init; }
    public DateTime CreatedAtUtc { get; init; }
    public string? CreatedByName { get; init; }
    public DateTime? UpdatedAtUtc { get; init; }

    public bool IsDraft => Status == InvoiceStatus.Draft;
    public bool IsIssued => Status == InvoiceStatus.Issued;
    public bool IsCancelled => Status == InvoiceStatus.Cancelled;
    public decimal TaxTotal => CgstTotal + SgstTotal + IgstTotal;
    public decimal Balance => GrandTotal - AmountPaid;
}

public sealed class InvoiceLine
{
    public long SalesInvoiceLineId { get; init; }
    public short LineNumber { get; init; }
    public long? OfferingId { get; init; }
    public string Description { get; init; } = "";
    public string? Details { get; init; }
    public string? HsnSacCode { get; init; }
    public decimal Quantity { get; init; }
    public string? UnitCode { get; init; }
    public string? UqcCode { get; init; }
    public decimal Rate { get; init; }
    public bool RateIncludesTax { get; init; }
    public decimal DiscountPercent { get; init; }
    public decimal GrossAmount { get; init; }
    public decimal DiscountAmount { get; init; }
    public decimal TaxableValue { get; init; }
    public long? TaxRateId { get; init; }
    public decimal TaxRatePercent { get; init; }
    public decimal CgstAmount { get; init; }
    public decimal SgstAmount { get; init; }
    public decimal IgstAmount { get; init; }
    public decimal LineTotal { get; init; }
    public bool IsPureAgent { get; init; }
    public string? PriceSource { get; init; }
}

/// <summary>What one item costs this customer, for a new invoice line.</summary>
public sealed class ItemForCustomer : ProcResult
{
    public decimal? Price { get; init; }
    public decimal? DefaultPrice { get; init; }
    public string? Source { get; init; }
    public string? PriceListName { get; init; }
    public bool IsPriceInclusive { get; init; }
    public long OfferingId { get; init; }
    public string OfferingName { get; init; } = "";
    public string? Description { get; init; }
    public string? HsnSacCode { get; init; }
    public bool IsPureAgent { get; init; }
    public byte OfferingType { get; init; }
    public long? TaxRateId { get; init; }
    public decimal TaxRatePercent { get; init; }
    public string? TaxName { get; init; }
    public string? UnitCode { get; init; }
    public string? UqcCode { get; init; }
    public decimal? LastSoldPrice { get; init; }
    public DateTime? LastSoldOn { get; init; }
    public decimal? LastSoldQty { get; init; }
    public string? LastInvoiceNo { get; init; }
}

public sealed class ItemMatch
{
    public long OfferingId { get; init; }
    public string OfferingName { get; init; } = "";
    public string? OfferingCode { get; init; }
    public string? HsnSacCode { get; init; }
    public decimal? DefaultPrice { get; init; }
    public bool IsPriceInclusive { get; init; }
    public string? UnitCode { get; init; }
    public string? TaxName { get; init; }
    public string? BrandName { get; init; }
    public bool BoughtBefore { get; init; }
}

public sealed class InvoiceSaveResult : ProcResult
{
    public string? FieldName { get; init; }
    public long SalesInvoiceId { get; init; }
    public bool IsNew { get; init; }
}

public sealed class IssueResult : ProcResult
{
    public string? InvoiceNumber { get; init; }
}

public sealed class CancelResult : ProcResult
{
    public bool Discarded { get; init; }
}

public sealed class InvoiceStore(IDb db)
{
    public Task<InvoicePage> ListAsync(long tenantId, string view, string? search, long? partyId, DateOnly today, int page, int pageSize, CancellationToken ct) =>
        db.MultipleAsync("dbo.usp_SalesInvoice_List",
            new { TenantId = tenantId, View = view, Search = search, PartyId = partyId, Today = today.ToDateTime(TimeOnly.MinValue), Page = page, PageSize = pageSize },
            async grid =>
            {
                var rows = (await grid.ReadAsync<InvoiceRow>()).ToList();
                var summary = await grid.ReadSingleAsync<InvoiceSummary>();
                return new InvoicePage(rows, summary, rows.FirstOrDefault()?.Total ?? 0, page, pageSize);
            }, ct);

    public Task<(Invoice? Invoice, IReadOnlyList<InvoiceLine> Lines)> GetAsync(long tenantId, long id, CancellationToken ct) =>
        db.MultipleAsync("dbo.usp_SalesInvoice_Get", new { TenantId = tenantId, SalesInvoiceId = id }, async grid =>
        {
            var invoice = await grid.ReadSingleOrDefaultAsync<Invoice>();
            IReadOnlyList<InvoiceLine> lines = (await grid.ReadAsync<InvoiceLine>()).ToList();
            return (invoice, lines);
        }, ct);

    public Task<InvoiceSaveResult> SaveAsync(object parameters, CancellationToken ct) =>
        db.ResultAsync<InvoiceSaveResult>("dbo.usp_SalesInvoice_Save", parameters, ct);

    public Task<IssueResult> IssueAsync(long tenantId, long id, string sellerSnapshot, DateOnly today, int? monthlyLimit, long userId, string? ip, CancellationToken ct) =>
        db.ResultAsync<IssueResult>("dbo.usp_SalesInvoice_Issue",
            new { TenantId = tenantId, SalesInvoiceId = id, SellerSnapshot = sellerSnapshot, Today = today.ToDateTime(TimeOnly.MinValue), MonthlyLimit = monthlyLimit, ActionByUserId = userId, IpAddress = ip }, ct);

    public Task<CancelResult> CancelAsync(long tenantId, long id, string? reason, long userId, string? ip, CancellationToken ct) =>
        db.ResultAsync<CancelResult>("dbo.usp_SalesInvoice_Cancel",
            new { TenantId = tenantId, SalesInvoiceId = id, Reason = reason, ActionByUserId = userId, IpAddress = ip }, ct);

    public Task<ItemForCustomer?> ItemForAsync(long tenantId, long offeringId, long? partyId, decimal quantity, DateOnly onDate, CancellationToken ct) =>
        db.SingleAsync<ItemForCustomer>("dbo.usp_SalesInvoice_ItemFor",
            new { TenantId = tenantId, OfferingId = offeringId, PartyId = partyId, Quantity = quantity, AsOnDate = onDate.ToDateTime(TimeOnly.MinValue) }, ct);

    public Task<IReadOnlyList<ItemMatch>> FindItemsAsync(long tenantId, string? search, long? partyId, CancellationToken ct) =>
        db.ListAsync<ItemMatch>("dbo.usp_SalesInvoice_FindItems", new { TenantId = tenantId, Search = search, PartyId = partyId }, ct);
}
