using System.Globalization;
using BillingMadeEasy.Data;

namespace BillingMadeEasy.Web.Infrastructure.Settings;

/// <summary>
/// Effective settings (user override → tenant override → platform default) from
/// usp_Setting_GetEffective. Rules such as password length live in the database, so an owner can
/// change them without a deployment.
/// </summary>
public sealed class SettingsReader(IDb db)
{
    private sealed class Row
    {
        public string SettingKey { get; init; } = "";
        public string? EffectiveValue { get; init; }
    }

    public async Task<int> GetIntAsync(long? tenantId, string key, int fallback, CancellationToken ct = default)
    {
        var row = await db.SingleAsync<Row>("dbo.usp_Setting_GetEffective", new { TenantId = tenantId, UserId = (long?)null, SettingKey = key }, ct);
        return int.TryParse(row?.EffectiveValue, NumberStyles.Integer, CultureInfo.InvariantCulture, out int value) ? value : fallback;
    }
}
