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

    public async Task<TenantEntitlements> GetAsync(long tenantId, CancellationToken cancellationToken = default)
    {
        try
        {
            return await ReadAsync(tenantId, cancellationToken);
        }
        catch (Microsoft.Data.SqlClient.SqlException e) when (e.Number == 2812)
        {
            throw new InvalidOperationException(
                "usp_Tenant_Entitlements_Get is missing. Run database/scripts/30_module_entitlements.sql on this database.", e);
        }
    }

    private Task<TenantEntitlements> ReadAsync(long tenantId, CancellationToken cancellationToken) =>
        db.MultipleAsync("dbo.usp_Tenant_Entitlements_Get", new { TenantId = tenantId }, async grid =>
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
