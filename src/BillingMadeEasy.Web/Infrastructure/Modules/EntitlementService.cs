using BillingMadeEasy.Core.Modules;
using Microsoft.Extensions.Caching.Memory;

namespace BillingMadeEasy.Web.Infrastructure.Modules;

/// <summary>
/// Resolves which modules a tenant may use right now. Cached for a minute per tenant, so a
/// super-admin grant or a self-serve add-on takes effect without the user signing out.
/// </summary>
public sealed class EntitlementService(IEntitlementStore store, IMemoryCache cache, TimeProvider clock)
{
    private static readonly TimeSpan Lifetime = TimeSpan.FromSeconds(60);

    public async Task<IReadOnlySet<string>> EnabledModulesAsync(long tenantId, CancellationToken ct = default) =>
        (await GetAsync(tenantId, ct)).EnabledModules(clock.GetUtcNow());

    public async Task<bool> IsEnabledAsync(long tenantId, string moduleKey, CancellationToken ct = default) =>
        (await EnabledModulesAsync(tenantId, ct)).Contains(moduleKey);

    public async Task<TenantEntitlements> GetAsync(long tenantId, CancellationToken ct = default) =>
        (await cache.GetOrCreateAsync(Key(tenantId), entry =>
        {
            entry.AbsoluteExpirationRelativeToNow = Lifetime;
            return store.GetAsync(tenantId, ct);
        }))!;

    /// <summary>Call after granting or revoking a module so the change is visible immediately.</summary>
    public void Invalidate(long tenantId) => cache.Remove(Key(tenantId));

    private static string Key(long tenantId) => $"entitlements:{tenantId}";
}
