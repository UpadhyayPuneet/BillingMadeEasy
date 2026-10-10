using BillingMadeEasy.Core;
using BillingMadeEasy.Data;

namespace BillingMadeEasy.Web.Features.Business;

public sealed class ProfileRow
{
    public long BusinessProfileId { get; init; }
    public string ProfileName { get; init; } = "";
    public string LegalName { get; init; } = "";
    public string? Gstin { get; init; }
    public string? StateCode { get; init; }
    public string? StateName { get; init; }
    public string? City { get; init; }
    public string? LogoPath { get; init; }
    public string? AccentColor { get; init; }
    public bool IsComposition { get; init; }
    public bool IsDefault { get; init; }
    public bool IsActive { get; init; }
    public int BankAccounts { get; init; }
    public string? NextInvoiceNumber { get; init; }
    public string? Missing { get; init; }
}

public sealed class BusinessProfile
{
    public long BusinessProfileId { get; init; }
    public string ProfileName { get; init; } = "";
    public string LegalName { get; init; } = "";
    public string? Gstin { get; init; }
    public string? Pan { get; init; }
    public string? StateCode { get; init; }
    public string? StateName { get; init; }
    public string? AddressLine1 { get; init; }
    public string? AddressLine2 { get; init; }
    public string? City { get; init; }
    public string? PostalCode { get; init; }
    public string? Phone { get; init; }
    public string? Email { get; init; }
    public string? Website { get; init; }
    public string? LogoPath { get; init; }
    public string? SignaturePath { get; init; }
    public string? SignatoryName { get; init; }
    public string? SignatoryTitle { get; init; }
    public string? AccentColor { get; init; }
    public string? UdyamNumber { get; init; }
    public string? Cin { get; init; }
    public bool IsComposition { get; init; }
    public string? LutNumber { get; init; }
    public string? InvoiceTerms { get; init; }
    public string? InvoiceNote { get; init; }
    public short? DefaultDueDays { get; init; }
    public bool RoundOffTotal { get; init; }
    public bool IsDefault { get; init; }
    public bool IsActive { get; init; }
    public DateTime? UpdatedAtUtc { get; init; }

    /// <summary>The address as printed, one line per entry.</summary>
    public IEnumerable<string> AddressLines()
    {
        if (!string.IsNullOrWhiteSpace(AddressLine1)) yield return AddressLine1!;
        if (!string.IsNullOrWhiteSpace(AddressLine2)) yield return AddressLine2!;
        string place = string.Join(" ", new[] { City, PostalCode }.Where(s => !string.IsNullOrWhiteSpace(s)));
        string withState = string.Join(", ", new[] { place, StateName }.Where(s => !string.IsNullOrWhiteSpace(s)));
        if (withState.Length > 0) yield return withState;
    }
}

public static class BankAccountType
{
    public const byte Current = 1;
    public const byte Savings = 2;
    public const byte CashCredit = 3;

    public static string Label(byte t) => t switch { Current => "Current", Savings => "Savings", CashCredit => "Cash credit / OD", _ => "Account" };
}

public sealed class BankAccount
{
    public long BankAccountId { get; init; }
    public string BankName { get; init; } = "";
    public string AccountName { get; init; } = "";
    public string AccountNumber { get; init; } = "";
    public string Ifsc { get; init; } = "";
    public string? BranchName { get; init; }
    public byte AccountType { get; init; }
    public string? UpiId { get; init; }
    public bool IsDefault { get; init; }

    /// <summary>Shown in lists: the last four digits, as banks do.</summary>
    public string Masked => AccountNumber.Length <= 4 ? AccountNumber : "••" + AccountNumber[^4..];
}

public sealed class SeriesRow
{
    public long SeriesId { get; init; }
    public byte DocumentType { get; init; }
    public string SeriesName { get; init; } = "";
    public string? Prefix { get; init; }
    public string? Suffix { get; init; }
    public string Separator { get; init; } = "-";
    public byte PadWidth { get; init; }
    public byte YearFormat { get; init; }
    public bool ResetYearly { get; init; }
    public int StartFrom { get; init; }
    public bool IsDefault { get; init; }
    public int NextSequence { get; init; }
    public string NextNumber { get; init; } = "";
    public int IssuedTotal { get; init; }
    public int IssuedThisYear { get; init; }
    public string? LastNumber { get; init; }
    public DateTime? LastIssuedUtc { get; init; }
}

public sealed class FieldResult : ProcResult
{
    public string? FieldName { get; init; }
}

public sealed class ProfileSaveResult : ProcResult
{
    public string? FieldName { get; init; }
    public long BusinessProfileId { get; init; }
    public bool IsNew { get; init; }
}

public sealed class ImageResult : ProcResult
{
    public string? OldPath { get; init; }
}

public sealed class BusinessStore(IDb db)
{
    public Task<IReadOnlyList<ProfileRow>> ListAsync(long tenantId, CancellationToken ct) =>
        db.ListAsync<ProfileRow>("dbo.usp_BusinessProfile_List", new { TenantId = tenantId }, ct);

    /// <summary>A profile and its bank accounts. Null id gives the default profile.</summary>
    public Task<(BusinessProfile? Profile, IReadOnlyList<BankAccount> Accounts)> GetAsync(long tenantId, long? profileId, CancellationToken ct) =>
        db.MultipleAsync("dbo.usp_BusinessProfile_Get", new { TenantId = tenantId, BusinessProfileId = profileId }, async grid =>
        {
            var profile = await grid.ReadSingleOrDefaultAsync<BusinessProfile>();
            IReadOnlyList<BankAccount> accounts = (await grid.ReadAsync<BankAccount>()).ToList();
            return (profile, accounts);
        }, ct);

    public Task<ProfileSaveResult> SaveAsync(object parameters, CancellationToken ct) =>
        db.ResultAsync<ProfileSaveResult>("dbo.usp_BusinessProfile_Save", parameters, ct);

    public Task<ImageResult> SetImageAsync(long tenantId, long profileId, byte kind, string? path, long userId, string? ip, CancellationToken ct) =>
        db.ResultAsync<ImageResult>("dbo.usp_BusinessProfile_SetImage",
            new { TenantId = tenantId, BusinessProfileId = profileId, Kind = kind, Path = path, ActionByUserId = userId, IpAddress = ip }, ct);

    public Task<FieldResult> SetActiveAsync(long tenantId, long profileId, bool active, long userId, string? ip, CancellationToken ct) =>
        db.ResultAsync<FieldResult>("dbo.usp_BusinessProfile_SetActive",
            new { TenantId = tenantId, BusinessProfileId = profileId, IsActive = active, ActionByUserId = userId, IpAddress = ip }, ct);

    public Task<FieldResult> SaveBankAccountAsync(object parameters, CancellationToken ct) =>
        db.ResultAsync<FieldResult>("dbo.usp_BankAccount_Save", parameters, ct);

    public Task<FieldResult> RemoveBankAccountAsync(long tenantId, long profileId, long accountId, long userId, string? ip, CancellationToken ct) =>
        db.ResultAsync<FieldResult>("dbo.usp_BankAccount_Remove",
            new { TenantId = tenantId, BusinessProfileId = profileId, BankAccountId = accountId, ActionByUserId = userId, IpAddress = ip }, ct);

    public Task<IReadOnlyList<SeriesRow>> SeriesAsync(long tenantId, long profileId, CancellationToken ct) =>
        db.ListAsync<SeriesRow>("dbo.usp_NumberSeries_ListForProfile", new { TenantId = tenantId, BusinessProfileId = profileId }, ct);

    public Task<FieldResult> SaveSeriesAsync(object parameters, CancellationToken ct) =>
        db.ResultAsync<FieldResult>("dbo.usp_NumberSeries_SaveForProfile", parameters, ct);

    public Task<FieldResult> RetireSeriesAsync(long tenantId, long profileId, long seriesId, long userId, string? ip, CancellationToken ct) =>
        db.ResultAsync<FieldResult>("dbo.usp_NumberSeries_Retire",
            new { TenantId = tenantId, BusinessProfileId = profileId, SeriesId = seriesId, ActionByUserId = userId, IpAddress = ip }, ct);
}
