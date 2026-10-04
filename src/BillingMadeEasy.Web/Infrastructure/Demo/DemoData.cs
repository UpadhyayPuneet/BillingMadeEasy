using BillingMadeEasy.Core.Modules;
using BillingMadeEasy.Core.Security;
using BillingMadeEasy.Web.Infrastructure.Auth;

namespace BillingMadeEasy.Web.Infrastructure.Demo;

/// <summary>
/// In-memory sign-in and entitlements so the shell runs on a laptop with no database.
/// Registered only in Development when <c>Auth:Provider</c> is <c>Demo</c>; startup refuses it anywhere else.
/// </summary>
public static class DemoData
{
    public const string Email = "owner@demo.test";
    public const string Password = "Demo@12345";

    private static readonly Lazy<string> Hash = new(() => PasswordHasher.Hash(Password));

    public static readonly TenantMembership[] Tenants =
    [
        new(1, "Yenetch Technologies", "Owner"),
        new(2, "Sharma Tyres", "Owner"),
    ];

    public static readonly IReadOnlyDictionary<long, string[]> Modules = new Dictionary<long, string[]>
    {
        [1] = [ModuleKeys.Billing, ModuleKeys.Subscriptions, ModuleKeys.Accounting, ModuleKeys.Operations],
        [2] = [ModuleKeys.Billing, ModuleKeys.Inventory, ModuleKeys.Purchases],
    };

    public static string PasswordHash => Hash.Value;
}

public sealed class DemoAuthService : IAuthService
{
    private static readonly string[] OwnerPermissions = ["*"];

    public Task<SignInOutcome> SignInAsync(string identifier, string password, RequestInfo request, CancellationToken ct = default)
    {
        bool ok = string.Equals(identifier.Trim(), DemoData.Email, StringComparison.OrdinalIgnoreCase)
                  && PasswordHasher.Verify(password, DemoData.PasswordHash);

        return Task.FromResult(ok
            ? new SignInOutcome(SignInStatus.Success, 1, "Demo Owner", IsPlatformAdmin: true, SessionKey: SecureTokens.UrlToken(), Email: DemoData.Email, Tenants: DemoData.Tenants)
            : new SignInOutcome(SignInStatus.InvalidCredentials));
    }

    public Task<IReadOnlyList<TenantMembership>> GetTenantsAsync(long userId, CancellationToken ct = default) =>
        Task.FromResult<IReadOnlyList<TenantMembership>>(userId == 1 ? DemoData.Tenants : []);

    public Task<TenantSession?> SelectTenantAsync(string sessionKey, long userId, long tenantId, CancellationToken ct = default)
    {
        var membership = userId == 1 ? DemoData.Tenants.FirstOrDefault(t => t.TenantId == tenantId) : null;
        return Task.FromResult(membership is null
            ? null
            : new TenantSession(membership.TenantId, membership.TenantName, membership.RoleName, OwnerPermissions));
    }

    /// <summary>Demo sessions never lock or expire server-side; the cookie lifetime still applies.</summary>
    public Task<SessionState> ValidateSessionAsync(string sessionKey, string? ipAddress, CancellationToken ct = default) =>
        Task.FromResult(new SessionState(SessionStatus.Active));

    public Task<SignInOutcome> UnlockAsync(string sessionKey, long userId, string password, RequestInfo request, CancellationToken ct = default) =>
        Task.FromResult(new SignInOutcome(PasswordHasher.Verify(password, DemoData.PasswordHash) ? SignInStatus.Success : SignInStatus.InvalidCredentials, userId));

    public Task<string> RenewSessionAsync(long userId, long? tenantId, RequestInfo request, CancellationToken ct = default) =>
        Task.FromResult(SecureTokens.UrlToken());

    public Task LockAsync(string sessionKey, CancellationToken ct = default) => Task.CompletedTask;

    public Task SignOutAsync(string sessionKey, CancellationToken ct = default) => Task.CompletedTask;
}

public sealed class DemoEntitlementStore : IEntitlementStore
{
    public Task<TenantEntitlements> GetAsync(long tenantId, CancellationToken cancellationToken = default)
    {
        var grants = DemoData.Modules.TryGetValue(tenantId, out var keys)
            ? keys.Select(k => new ModuleEntitlement(k, EntitlementSource.Plan, null)).ToList()
            : [];
        return Task.FromResult(new TenantEntitlements(tenantId, "demo", grants, new Dictionary<string, int>()));
    }
}
