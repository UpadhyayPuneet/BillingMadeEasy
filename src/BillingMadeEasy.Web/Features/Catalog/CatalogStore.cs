using BillingMadeEasy.Core;
using BillingMadeEasy.Data;

namespace BillingMadeEasy.Web.Features.Catalog;

public static class OfferingType
{
    public const byte Product = 1;
    public const byte Service = 2;
    public const byte Expense = 3;

    public static string Label(byte type) => type switch { Product => "Product", Service => "Service", Expense => "Expense", _ => "Item" };
}

/// <summary>tbl_TaxRates.TaxType.</summary>
public static class TaxKind
{
    public const byte Gst = 1;
    public const byte Nil = 2;
    public const byte Exempt = 3;
    public const byte NonGst = 4;
    public const byte ZeroRated = 5;
}

public sealed class OfferingRow
{
    public long OfferingId { get; init; }
    public byte OfferingType { get; init; }
    public string OfferingName { get; init; } = "";
    public string? OfferingCode { get; init; }
    public string? Description { get; init; }
    public decimal? DefaultPrice { get; init; }
    public decimal? DefaultCost { get; init; }
    public bool IsPriceInclusive { get; init; }
    public bool IsPureAgent { get; init; }
    public string? HsnSacCode { get; init; }
    public bool IsRecurring { get; init; }
    public bool IsActive { get; init; }
    public string? CategoryName { get; init; }
    public string? BrandName { get; init; }
    public string? UnitCode { get; init; }
    public string? TaxName { get; init; }
    public decimal? RatePercent { get; init; }
    public byte? TaxType { get; init; }
    public long? TaxRateId { get; init; }
    public bool HasPrice { get; init; }
    public int PriceListCount { get; init; }
}

public sealed record OfferingPage(IReadOnlyList<OfferingRow> Rows, int Total, int Page, int PageSize)
{
    public int Pages => Math.Max(1, (int)Math.Ceiling(Total / (double)PageSize));
}

public sealed class Offering : ProcResult
{
    public long Id { get; init; }
    public byte OfferingType { get; init; }
    public string OfferingName { get; init; } = "";
    public string? OfferingCode { get; init; }
    public string? Description { get; init; }
    public long? CategoryId { get; init; }
    public long? UnitId { get; init; }
    public long? TaxRateId { get; init; }
    public decimal? DefaultPrice { get; init; }
    public decimal? DefaultCost { get; init; }
    public bool IsPriceInclusive { get; init; }
    public bool IsPureAgent { get; init; }
    public string? HsnSacCode { get; init; }
    public bool IsRecurring { get; init; }
    public bool IsSellable { get; init; }
    public bool IsPurchasable { get; init; }
    public bool IsActive { get; init; }
    public string? BrandName { get; init; }
    public string? Barcode { get; init; }
    public string? PackSize { get; init; }
    public bool? TracksStock { get; init; }
    public decimal? ReorderLevel { get; init; }
}

public sealed class UnitOption
{
    public long UnitId { get; init; }
    public string UnitName { get; init; } = "";
    public string UnitCode { get; init; } = "";
    public string? UqcCode { get; init; }
    public byte DecimalPlaces { get; init; }
}

public sealed class TaxOption
{
    public long TaxRateId { get; init; }
    public string TaxName { get; init; } = "";
    public byte TaxType { get; init; }
    public decimal RatePercent { get; init; }
    public decimal CessPercent { get; init; }
    public bool IsDefault { get; init; }
}

public sealed class CategoryOption
{
    public long CategoryId { get; init; }
    public string CategoryName { get; init; } = "";
}

public sealed class BrandMatch
{
    public long ProductBrandId { get; init; }
    public string BrandName { get; init; } = "";
    public int MatchRank { get; init; }
}

public sealed class CustomerPrice
{
    public long PriceListItemId { get; init; }
    public long PartyId { get; init; }
    public string PartyName { get; init; } = "";
    public decimal MinQuantity { get; init; }
    public decimal? Price { get; init; }
    public decimal? DiscountPercent { get; init; }
    public DateTime? UpdatedAtUtc { get; init; }
    public DateTime CreatedAtUtc { get; init; }
}

public sealed class OfferingSaveResult : ProcResult
{
    public long OfferingId { get; init; }
    public bool IsNew { get; init; }
    public string? FieldName { get; init; }
}

public sealed class FieldResult : ProcResult
{
    public string? FieldName { get; init; }
}

public sealed class CategorySaveResult : ProcResult
{
    public long CategoryId { get; init; }
    public string? FieldName { get; init; }
}

/// <summary>Products, services and expenses through the usp_Offering* procedures.</summary>
public sealed class CatalogStore(IDb db)
{
    public Task<OfferingPage> ListAsync(long tenantId, byte? type, string? search, bool includeInactive, int page, int pageSize, CancellationToken ct) =>
        db.MultipleAsync("dbo.usp_Offering_List",
            new { TenantId = tenantId, OfferingType = type, Search = search, IncludeInactive = includeInactive, Page = page, PageSize = pageSize },
            async grid => new OfferingPage((await grid.ReadAsync<OfferingRow>()).ToList(), await grid.ReadSingleAsync<int>(), page, pageSize), ct);

    public async Task<Offering?> GetAsync(long tenantId, long id, CancellationToken ct) =>
        await db.SingleAsync<Offering>("dbo.usp_Offering_Get", new { TenantId = tenantId, OfferingId = id }, ct) is { Id: > 0 } o ? o : null;

    public Task<OfferingSaveResult> SaveAsync(object parameters, CancellationToken ct) =>
        db.ResultAsync<OfferingSaveResult>("dbo.usp_Offering_Save", parameters, ct);

    public Task<ProcResult> SetActiveAsync(long tenantId, long id, bool active, long userId, string? ip, CancellationToken ct) =>
        db.ResultAsync<ProcResult>("dbo.usp_Offering_SetActive", new { TenantId = tenantId, OfferingId = id, IsActive = active, ActionByUserId = userId, IpAddress = ip }, ct);

    public Task<IReadOnlyList<UnitOption>> UnitsAsync(long tenantId, CancellationToken ct) =>
        db.ListAsync<UnitOption>("dbo.usp_Unit_List", new { TenantId = tenantId }, ct);

    public Task<IReadOnlyList<TaxOption>> TaxRatesAsync(long tenantId, CancellationToken ct) =>
        db.ListAsync<TaxOption>("dbo.usp_TaxRate_List", new { TenantId = tenantId, AsOnDate = (DateTime?)null }, ct);

    public Task<IReadOnlyList<CategoryOption>> CategoriesAsync(long tenantId, CancellationToken ct) =>
        db.ListAsync<CategoryOption>("dbo.usp_Category_List", new { TenantId = tenantId, AppliesTo = (byte)2 }, ct);

    public Task<CategorySaveResult> AddCategoryAsync(long tenantId, string name, long userId, string? ip, CancellationToken ct) =>
        db.ResultAsync<CategorySaveResult>("dbo.usp_Category_Save",
            new { TenantId = tenantId, CategoryId = 0L, CategoryName = name, AppliesTo = (byte)2, Description = (string?)null, ActionByUserId = userId, IpAddress = ip }, ct);

    public Task<IReadOnlyList<BrandMatch>> SearchBrandsAsync(long tenantId, string? term, CancellationToken ct) =>
        db.ListAsync<BrandMatch>("dbo.usp_ProductBrand_Search", new { TenantId = tenantId, Term = term, Top = 8 }, ct);

    public Task<IReadOnlyList<CustomerPrice>> CustomerPricesAsync(long tenantId, long offeringId, CancellationToken ct) =>
        db.ListAsync<CustomerPrice>("dbo.usp_PartyPrice_List", new { TenantId = tenantId, OfferingId = offeringId }, ct);

    public Task<FieldResult> SetCustomerPriceAsync(long tenantId, long offeringId, long partyId, decimal minQty, decimal? price, decimal? discount,
        long userId, string? ip, CancellationToken ct) =>
        db.ResultAsync<FieldResult>("dbo.usp_PartyPrice_Set", new
        {
            TenantId = tenantId, OfferingId = offeringId, PartyId = partyId, MinQuantity = minQty,
            Price = price, DiscountPercent = discount, ActionByUserId = userId, IpAddress = ip,
        }, ct);

    public Task<ProcResult> RemoveCustomerPriceAsync(long tenantId, long itemId, long userId, string? ip, CancellationToken ct) =>
        db.ResultAsync<ProcResult>("dbo.usp_PartyPrice_Remove", new { TenantId = tenantId, PriceListItemId = itemId, ActionByUserId = userId, IpAddress = ip }, ct);
}
