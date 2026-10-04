using BillingMadeEasy.Core;
using BillingMadeEasy.Core.Modules;

namespace BillingMadeEasy.Data;

/// <summary>Reads <c>usp_Tenant_Entitlements_Get</c> (database/scripts/30_module_entitlements.sql).</summary>
public sealed class SqlEntitlementStore(IDb db) : IEntitlementStore
{
    private sealed class Header : ProcResult
    {
        public string PlanCode { get; init; } = "";
    }

    private sealed record GrantRow(string ModuleKey, byte Source, DateTime? ExpiresAt);

    private sealed record LimitRow(string Meter, int LimitValue);

    public Task<TenantEntitlements> GetAsync(long tenantId, CancellationToken cancellationToken = default) =>
        db.MultipleAsync("dbo.usp_Tenant_Entitlements_Get", new { TenantId = checked((int)tenantId) }, async grid =>
        {
            var header = await grid.ReadSingleAsync<Header>();
            var grants = (await grid.ReadAsync<GrantRow>())
                .Select(g => new ModuleEntitlement(
                    g.ModuleKey,
                    (EntitlementSource)g.Source,
                    g.ExpiresAt is { } e ? new DateTimeOffset(DateTime.SpecifyKind(e, DateTimeKind.Utc)) : null))
                .ToList();
            var limits = (await grid.ReadAsync<LimitRow>()).ToDictionary(l => l.Meter, l => l.LimitValue, StringComparer.OrdinalIgnoreCase);

            return new TenantEntitlements(tenantId, header.Succeeded ? header.PlanCode : "", grants, limits);
        }, cancellationToken);
}
