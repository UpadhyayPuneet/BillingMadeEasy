using System.Security.Claims;

namespace BillingMadeEasy.Core.Tenancy;

/// <summary>Claim names on the signed-in principal. Identity is global; the tenant claim is the
/// workspace this session is operating in, set at tenant selection and re-checked server-side.</summary>
public static class AppClaims
{
    public const string UserId = "bme:uid";
    public const string TenantId = "bme:tid";
    public const string TenantName = "bme:tname";
    public const string SessionKey = "bme:sid";
    public const string Permission = "bme:perm";
    public const string PlatformAdmin = "bme:padmin";

    public static long? GetUserId(this ClaimsPrincipal user) => ParseLong(user.FindFirst(UserId)?.Value);

    public static long? GetTenantId(this ClaimsPrincipal user) => ParseLong(user.FindFirst(TenantId)?.Value);

    /// <summary>Permission codes are dotted (<c>Sales.Invoice.Issue</c>). <c>*</c> grants everything and is
    /// only ever issued to a tenant owner.</summary>
    public static bool HasPermission(this ClaimsPrincipal user, string code) =>
        user.HasClaim(c => c.Type == Permission
                           && (c.Value == AllPermissions || string.Equals(c.Value, code, StringComparison.OrdinalIgnoreCase)));

    public const string AllPermissions = "*";

    private static long? ParseLong(string? value) => long.TryParse(value, out long id) ? id : null;
}
