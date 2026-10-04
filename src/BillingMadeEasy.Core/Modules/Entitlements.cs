namespace BillingMadeEasy.Core.Modules;

public enum EntitlementSource
{
    Plan = 1,
    AddOn = 2,
    PlatformGrant = 3,
    Trial = 4,
}

public sealed record ModuleEntitlement(string ModuleKey, EntitlementSource Source, DateTimeOffset? ExpiresAt);

/// <summary>What a tenant has paid for or been granted, resolved once and cached briefly.</summary>
public sealed record TenantEntitlements(
    long TenantId,
    string PlanCode,
    IReadOnlyList<ModuleEntitlement> Grants,
    IReadOnlyDictionary<string, int> Limits)
{
    public IReadOnlySet<string> EnabledModules(DateTimeOffset now) =>
        ModuleCatalog.Effective(Grants.Where(g => g.ExpiresAt is null || g.ExpiresAt > now).Select(g => g.ModuleKey));

    /// <summary>Plan limit for a meter (users, branches, invoices per month); null means unlimited.</summary>
    public int? Limit(string meter) => Limits.TryGetValue(meter, out int value) ? value : null;
}

public static class Meters
{
    public const string Users = "users";
    public const string Branches = "branches";
    public const string InvoicesPerMonth = "invoices_per_month";
}

public interface IEntitlementStore
{
    Task<TenantEntitlements> GetAsync(long tenantId, CancellationToken cancellationToken = default);
}
