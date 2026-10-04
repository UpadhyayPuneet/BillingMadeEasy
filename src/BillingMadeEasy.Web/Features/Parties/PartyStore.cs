using BillingMadeEasy.Core;
using BillingMadeEasy.Data;

namespace BillingMadeEasy.Web.Features.Parties;

public sealed class PartyRow
{
    public long PartyId { get; init; }
    public string? PartyCode { get; init; }
    public byte PartyType { get; init; }
    public string LegalName { get; init; } = "";
    public string DisplayName { get; init; } = "";
    public string? TaxIdNumber { get; init; }
    public string? Email { get; init; }
    public string? Phone { get; init; }
    public byte Status { get; init; }
    public bool IsActive { get; init; }
    public string? CategoryName { get; init; }
    public bool IsCustomer { get; init; }
    public bool IsSupplier { get; init; }
    public bool IsBlocked { get; init; }
    public int LocationCount { get; init; }
    public int ContactCount { get; init; }
    public string? PrimaryCity { get; init; }
}

public sealed record PartyPage(IReadOnlyList<PartyRow> Rows, int Total, int Page, int PageSize)
{
    public int Pages => Math.Max(1, (int)Math.Ceiling(Total / (double)PageSize));
}

public sealed class PartyHeader : ProcResult
{
    public long PartyId { get; init; }
    public string? PartyCode { get; init; }
    public byte PartyType { get; init; }
    public string LegalName { get; init; } = "";
    public string? TradingName { get; init; }
    public string DisplayName { get; init; } = "";
    public string? TaxIdNumber { get; init; }
    public long? CategoryId { get; init; }
    public string? CategoryName { get; init; }
    public string? Email { get; init; }
    public string? Phone { get; init; }
    public string? Website { get; init; }
    public string? Notes { get; init; }
    public byte Status { get; init; }
    public bool IsActive { get; init; }
    public DateTime CreatedAtUtc { get; init; }
}

public sealed class PartyRole
{
    public byte RoleType { get; init; }
    public int? PaymentTermDays { get; init; }
    public decimal? CreditLimit { get; init; }
    public decimal OpeningBalance { get; init; }
    public bool IsBlocked { get; init; }
    public string? BlockReason { get; init; }
}

public sealed class PartyAddress
{
    public long PartyAddressId { get; init; }
    public byte AddressType { get; init; }
    public string? AddressLabel { get; init; }
    public string Line1 { get; init; } = "";
    public string? Line2 { get; init; }
    public string? Line3 { get; init; }
    public string? City { get; init; }
    public string? StateCode { get; init; }
    public string? StateName { get; init; }
    public string? PostalCode { get; init; }
    public bool IsDefault { get; init; }
    public string OneLine { get; init; } = "";
    public int UsedByLocations { get; init; }
}

public sealed class PartyLocation
{
    public long PartyLocationId { get; init; }
    public string LocationName { get; init; } = "";
    public string? LocationCode { get; init; }
    public string? Gstin { get; init; }
    public long? AddressId { get; init; }
    public string? Phone { get; init; }
    public string? Email { get; init; }
    public bool IsDefault { get; init; }
    public string? City { get; init; }
    public string? StateCode { get; init; }
    public string? StateName { get; init; }
    public int ContactCount { get; init; }
}

public sealed class PartyContact
{
    public long PartyContactId { get; init; }
    public long? PartyLocationId { get; init; }
    public string ContactName { get; init; } = "";
    public string? Designation { get; init; }
    public string? Department { get; init; }
    public string? Phone { get; init; }
    public string? Mobile { get; init; }
    public string? Email { get; init; }
    public string? Notes { get; init; }
    public bool IsPrimary { get; init; }
    public string? LocationName { get; init; }
}

public sealed class PartyBrand
{
    public long PartyBrandId { get; init; }
    public string BrandName { get; init; } = "";
    public string? BrandCode { get; init; }
    public string? Description { get; init; }
}

public sealed record PartyDetail(
    PartyHeader Party,
    IReadOnlyList<PartyRole> Roles,
    IReadOnlyList<PartyAddress> Addresses,
    IReadOnlyList<PartyLocation> Locations,
    IReadOnlyList<PartyContact> Contacts,
    IReadOnlyList<PartyBrand> Brands)
{
    public PartyRole? Customer => Roles.FirstOrDefault(r => r.RoleType == Core.Parties.PartyCodes.RoleCustomer);
    public PartyRole? Supplier => Roles.FirstOrDefault(r => r.RoleType == Core.Parties.PartyCodes.RoleSupplier);
}

/// <summary>A save that the procedure refused, with the field it points at (for inline errors).</summary>
public class SaveResult : ProcResult
{
    public string? FieldName { get; init; }
}

public sealed class PartySaveResult : SaveResult
{
    public long PartyId { get; init; }
    public bool IsNew { get; init; }
}

public sealed class LocationSaveResult : SaveResult
{
    public long PartyLocationId { get; init; }
}

public sealed record PossibleDuplicate(long PartyId, string DisplayName, string? TaxIdNumber, string? PartyCode, string MatchOn);

public sealed record Lookup(long Id, string Name);

public sealed class GstinOwner
{
    public long PartyId { get; init; }
    public string DisplayName { get; init; } = "";
    public bool IsActive { get; init; }
    public string LocationName { get; init; } = "";
}

public sealed class StateOption
{
    public string StateCode { get; init; } = "";
    public string StateName { get; init; } = "";
}

/// <summary>
/// Everything about customers and suppliers goes through the usp_Party* procedures. Tenant and
/// acting user come from the session, never from the form.
/// </summary>
public sealed class PartyStore(IDb db)
{
    public async Task<PartyPage> ListAsync(long tenantId, byte? role, string? search, int page, int pageSize, CancellationToken ct) =>
        await db.MultipleAsync("dbo.usp_Party_List",
            new { TenantId = tenantId, RoleType = role, Search = search, Page = page, PageSize = pageSize },
            async grid =>
            {
                var rows = (await grid.ReadAsync<PartyRow>()).ToList();
                int total = await grid.ReadSingleAsync<int>();
                return new PartyPage(rows, total, page, pageSize);
            }, ct);

    /// <summary>The party that already has a branch with this exact GSTIN, if any.</summary>
    public Task<GstinOwner?> FindByGstinAsync(long tenantId, string gstin, CancellationToken ct) =>
        db.SingleAsync<GstinOwner>("dbo.usp_Party_FindByGstin", new { TenantId = tenantId, Gstin = gstin }, ct);

    public async Task<PartyDetail?> GetAsync(long tenantId, long partyId, CancellationToken ct)
    {
        var (header, roles) = await db.MultipleAsync("dbo.usp_Party_Get", new { TenantId = tenantId, PartyId = partyId },
            async grid => (await grid.ReadSingleOrDefaultAsync<PartyHeader>(), (await grid.ReadAsync<PartyRole>()).ToList()), ct);
        if (header is null || !header.Succeeded || header.PartyId == 0) return null;

        return await db.MultipleAsync("dbo.usp_Party_GetDetail", new { TenantId = tenantId, PartyId = partyId },
            async grid => new PartyDetail(header, roles,
                (await grid.ReadAsync<PartyAddress>()).ToList(),
                (await grid.ReadAsync<PartyLocation>()).ToList(),
                (await grid.ReadAsync<PartyContact>()).ToList(),
                (await grid.ReadAsync<PartyBrand>()).ToList()), ct);
    }

    public Task<(PartySaveResult Result, IReadOnlyList<PossibleDuplicate> Duplicates)> SaveAsync(object parameters, CancellationToken ct) =>
        db.MultipleAsync("dbo.usp_Party_Save", parameters, async grid =>
        {
            var result = await grid.ReadSingleAsync<PartySaveResult>();
            IReadOnlyList<PossibleDuplicate> duplicates = result.Succeeded && !grid.IsConsumed
                ? (await grid.ReadAsync<PossibleDuplicate>()).ToList()
                : [];
            return (result, duplicates);
        }, ct);

    public Task<ProcResult> SetStatusAsync(long tenantId, long partyId, byte? status, bool? isActive, string? reason, long userId, string? ip, CancellationToken ct) =>
        db.ResultAsync<ProcResult>("dbo.usp_Party_SetStatus",
            new { TenantId = tenantId, PartyId = partyId, Status = status, IsActive = isActive, Reason = reason, ActionByUserId = userId, IpAddress = ip }, ct);

    public Task<LocationSaveResult> SaveLocationAsync(object parameters, CancellationToken ct) =>
        db.ResultAsync<LocationSaveResult>("dbo.usp_PartyLocation_Save", parameters, ct);

    public Task<SaveResult> SaveAddressAsync(object parameters, CancellationToken ct) =>
        db.ResultAsync<SaveResult>("dbo.usp_PartyAddress_Save", parameters, ct);

    public Task<SaveResult> SaveContactAsync(object parameters, CancellationToken ct) =>
        db.ResultAsync<SaveResult>("dbo.usp_PartyContact_Save", parameters, ct);

    public Task<SaveResult> SaveBrandAsync(object parameters, CancellationToken ct) =>
        db.ResultAsync<SaveResult>("dbo.usp_PartyBrand_Save", parameters, ct);

    public Task<SaveResult> DeleteAsync(string kind, long tenantId, long partyId, long id, long userId, string? ip, CancellationToken ct) => kind switch
    {
        "location" => db.ResultAsync<SaveResult>("dbo.usp_PartyLocation_Delete", new { TenantId = tenantId, PartyId = partyId, PartyLocationId = id, ActionByUserId = userId, IpAddress = ip }, ct),
        "address" => db.ResultAsync<SaveResult>("dbo.usp_PartyAddress_Delete", new { TenantId = tenantId, PartyId = partyId, PartyAddressId = id, ActionByUserId = userId, IpAddress = ip }, ct),
        "contact" => db.ResultAsync<SaveResult>("dbo.usp_PartyContact_Delete", new { TenantId = tenantId, PartyId = partyId, PartyContactId = id, ActionByUserId = userId, IpAddress = ip }, ct),
        "brand" => db.ResultAsync<SaveResult>("dbo.usp_PartyBrand_Delete", new { TenantId = tenantId, PartyId = partyId, PartyBrandId = id, ActionByUserId = userId, IpAddress = ip }, ct),
        _ => throw new ArgumentOutOfRangeException(nameof(kind)),
    };

    public async Task<IReadOnlyList<Lookup>> CategoriesAsync(long tenantId, CancellationToken ct) =>
        (await db.ListAsync<CategoryRow>("dbo.usp_Category_List", new { TenantId = tenantId, AppliesTo = (byte)1 }, ct))
        .Select(c => new Lookup(c.CategoryId, c.CategoryName)).ToList();

    public Task<IReadOnlyList<StateOption>> StatesAsync(CancellationToken ct) =>
        db.ListAsync<StateOption>("dbo.usp_State_List", new { CountryCode = "IN" }, ct);

    private sealed class CategoryRow
    {
        public long CategoryId { get; init; }
        public string CategoryName { get; init; } = "";
    }
}
