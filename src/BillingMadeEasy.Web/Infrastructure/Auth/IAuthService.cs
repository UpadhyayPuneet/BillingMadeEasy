namespace BillingMadeEasy.Web.Infrastructure.Auth;

public enum SignInStatus
{
    Success,
    InvalidCredentials,
    Locked,
    NoActiveBusiness,
}

public sealed record RequestInfo(string? IpAddress, string? UserAgent)
{
    public static RequestInfo From(HttpContext http) =>
        new(http.Connection.RemoteIpAddress?.ToString(), http.Request.Headers.UserAgent.ToString() is { Length: > 0 } ua ? ua[..Math.Min(ua.Length, 400)] : null);
}

public sealed record TenantMembership(long TenantId, string TenantName, string RoleName);

/// <param name="SessionKey">Raw session key; only its hash is stored server-side.</param>
/// <param name="LockedUntil">Null with <see cref="SignInStatus.Locked"/> means locked until released.</param>
public sealed record SignInOutcome(
    SignInStatus Status,
    long UserId = 0,
    string DisplayName = "",
    bool IsPlatformAdmin = false,
    bool MustChangePassword = false,
    string SessionKey = "",
    IReadOnlyList<TenantMembership>? Tenants = null,
    DateTimeOffset? LockedUntil = null);

public sealed record TenantSession(long TenantId, string TenantName, string RoleName, IReadOnlyList<string> Permissions);

public enum SessionStatus
{
    Active,
    /// <summary>Idle too long: the person must re-enter their password before continuing.</summary>
    Locked,
    /// <summary>Ended, expired, or invalidated by a password change or an admin lock.</summary>
    Invalid,
}

public sealed record SessionState(SessionStatus Status, long? TenantId = null, int IdleLockMinutes = 0);

/// <summary>
/// The sign-in pipeline: resolve identity, verify the secret in C# (SQL only compares hashes),
/// register the attempt for lockout, then open a server-side session that every request re-checks.
/// </summary>
public interface IAuthService
{
    Task<SignInOutcome> SignInAsync(string identifier, string password, RequestInfo request, CancellationToken ct = default);

    Task<IReadOnlyList<TenantMembership>> GetTenantsAsync(long userId, CancellationToken ct = default);

    /// <summary>Re-checks membership server-side; a tampered tenant id returns null.</summary>
    Task<TenantSession?> SelectTenantAsync(string sessionKey, long userId, long tenantId, CancellationToken ct = default);

    Task<SessionState> ValidateSessionAsync(string sessionKey, string? ipAddress, CancellationToken ct = default);

    Task<SignInOutcome> UnlockAsync(string sessionKey, long userId, string password, RequestInfo request, CancellationToken ct = default);

    /// <summary>Locks the session now; it stays locked until the password is entered.</summary>
    Task LockAsync(string sessionKey, CancellationToken ct = default);

    Task SignOutAsync(string sessionKey, CancellationToken ct = default);
}
