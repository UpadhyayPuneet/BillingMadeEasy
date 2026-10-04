namespace BillingMadeEasy.Web.Infrastructure.Auth;

public enum SignInStatus
{
    Success,
    InvalidCredentials,
    Locked,
    Blocked,
    NoActiveBusiness,
}

public sealed record TenantMembership(long TenantId, string TenantName, string RoleName);

public sealed record SignInOutcome(
    SignInStatus Status,
    long UserId = 0,
    string DisplayName = "",
    bool IsPlatformAdmin = false,
    IReadOnlyList<TenantMembership>? Tenants = null,
    DateTimeOffset? LockedUntil = null);

public sealed record TenantSession(long TenantId, string TenantName, string RoleName, IReadOnlyList<string> Permissions);

/// <summary>
/// The sign-in pipeline: resolve identity, verify the secret in C# (SQL only compares hashes),
/// register the attempt for lockout and throttling, then list the businesses this person belongs to.
/// </summary>
public interface IAuthService
{
    Task<SignInOutcome> SignInAsync(string identifier, string password, string? ipAddress, CancellationToken ct = default);

    Task<IReadOnlyList<TenantMembership>> GetTenantsAsync(long userId, CancellationToken ct = default);

    /// <summary>Re-checks membership server-side; a tampered tenant id returns null.</summary>
    Task<TenantSession?> SelectTenantAsync(long userId, long tenantId, CancellationToken ct = default);
}
