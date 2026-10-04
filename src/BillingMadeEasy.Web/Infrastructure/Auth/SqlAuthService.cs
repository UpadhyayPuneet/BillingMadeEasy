using BillingMadeEasy.Core;
using BillingMadeEasy.Core.Security;
using BillingMadeEasy.Data;

namespace BillingMadeEasy.Web.Infrastructure.Auth;

/// <summary>Sign-in over the <c>usp_Auth_*</c> procedures in BME_db.</summary>
public sealed class SqlAuthService(IDb db, ILogger<SqlAuthService> log) : IAuthService
{
    private const int SessionLifetimeHours = 12;

    /// <summary>Verified when the identity is unknown, so a miss costs the same time as a wrong password.</summary>
    private static readonly Lazy<string> DummyHash = new(() => PasswordHasher.Hash(SecureTokens.UrlToken()));

    private sealed class BlockRow : ProcResult
    {
        public bool IsBlocked { get; init; }
        public DateTime? BlockedUntilUtc { get; init; }
    }

    private sealed class IdentityRow : ProcResult
    {
        public long UserId { get; init; }
        public string FullName { get; init; } = "";
    }

    private sealed class CredentialRow : ProcResult
    {
        public long UserId { get; init; }
        public string? PasswordHash { get; init; }
        public bool IsPlatformAdmin { get; init; }
        public bool MustChangePassword { get; init; }
        public string FullName { get; init; } = "";
    }

    private sealed class TenantRow
    {
        public long TenantId { get; init; }
        public string DisplayName { get; init; } = "";
        public bool IsTenantOwner { get; init; }
        public string? RoleNames { get; init; }
    }

    private sealed class SessionRow : ProcResult
    {
        public long? TenantId { get; init; }
        public bool IsLocked { get; init; }
        public int IdleLockMinutes { get; init; }
    }

    public async Task<SignInOutcome> SignInAsync(string identifier, string password, RequestInfo request, CancellationToken ct = default)
    {
        identifier = identifier.Trim();

        if (await BlockedAsync(null, identifier, request, ct) is { } blockedEarly) return blockedEarly;

        var identity = await db.ResultAsync<IdentityRow>("dbo.usp_Auth_Identity_Resolve", new { Identifier = identifier }, ct);
        if (!identity.Succeeded)
        {
            PasswordHasher.Verify(password, DummyHash.Value);
            var reason = identity.ResultCode == 6 ? AttemptFailure.Disabled : AttemptFailure.UnknownIdentity;
            long? knownUser = identity.ResultCode == 6 ? identity.UserId : null;
            return await FailAsync(knownUser, identifier, AttemptType.Identity, reason, request, ct);
        }

        if (await BlockedAsync(identity.UserId, identifier, request, ct) is { } blocked) return blocked;

        var credential = await db.ResultAsync<CredentialRow>("dbo.usp_Auth_Credential_Get", new { identity.UserId }, ct);
        if (credential.PasswordHash is null)
        {
            PasswordHasher.Verify(password, DummyHash.Value);
            return await FailAsync(identity.UserId, identifier, AttemptType.Password, AttemptFailure.NoPasswordSet, request, ct);
        }
        if (!PasswordHasher.Verify(password, credential.PasswordHash))
            return await FailAsync(identity.UserId, identifier, AttemptType.Password, AttemptFailure.WrongSecret, request, ct);

        await RegisterAsync(identity.UserId, identifier, AttemptType.Password, true, null, request, ct);

        if (PasswordHasher.NeedsRehash(credential.PasswordHash))
            await db.ResultAsync<ProcResult>("dbo.usp_Auth_Credential_UpgradeHash",
                new { identity.UserId, NewPasswordHash = PasswordHasher.Hash(password) }, ct);

        var tenants = await GetTenantsAsync(identity.UserId, ct);
        if (tenants.Count == 0) return new SignInOutcome(SignInStatus.NoActiveBusiness);

        string sessionKey = SecureTokens.UrlToken();
        await db.ResultAsync<ProcResult>("dbo.usp_Auth_Session_Create", new
        {
            identity.UserId,
            TenantId = (long?)null,
            DeviceId = (long?)null,
            SessionKeyHash = SecureTokens.SessionKeyHash(sessionKey),
            AuthMethod = (byte)AuthMethod.Password,
            request.IpAddress,
            request.UserAgent,
            LifetimeHours = SessionLifetimeHours,
        }, ct);

        return new SignInOutcome(SignInStatus.Success, identity.UserId, credential.FullName, credential.IsPlatformAdmin,
            credential.MustChangePassword, sessionKey, tenants);
    }

    public async Task<IReadOnlyList<TenantMembership>> GetTenantsAsync(long userId, CancellationToken ct = default) =>
        (await db.ListAsync<TenantRow>("dbo.usp_Auth_UserTenants_Get", new { UserId = userId }, ct))
        .Select(t => new TenantMembership(t.TenantId, t.DisplayName,
            !string.IsNullOrWhiteSpace(t.RoleNames) ? t.RoleNames! : t.IsTenantOwner ? "Owner" : "Member"))
        .ToList();

    public async Task<TenantSession?> SelectTenantAsync(string sessionKey, long userId, long tenantId, CancellationToken ct = default)
    {
        var result = await db.ResultAsync<ProcResult>("dbo.usp_Auth_Session_SelectTenant",
            new { SessionKeyHash = SecureTokens.SessionKeyHash(sessionKey), TenantId = tenantId }, ct);
        if (!result.Succeeded)
        {
            log.LogWarning("Tenant {TenantId} refused for user {UserId}: {Code}", tenantId, userId, result.ResultCode);
            return null;
        }

        var membership = (await GetTenantsAsync(userId, ct)).FirstOrDefault(t => t.TenantId == tenantId);
        if (membership is null) return null;

        var permissions = await db.ListAsync<string>("dbo.usp_Auth_Permissions_Get", new { UserId = userId, TenantId = tenantId }, ct);
        return new TenantSession(tenantId, membership.TenantName, membership.RoleName, permissions);
    }

    public async Task<SessionState> ValidateSessionAsync(string sessionKey, string? ipAddress, CancellationToken ct = default)
    {
        var row = await db.ResultAsync<SessionRow>("dbo.usp_Auth_Session_Validate",
            new { SessionKeyHash = SecureTokens.SessionKeyHash(sessionKey), IpAddress = ipAddress }, ct);
        if (!row.Succeeded) return new SessionState(SessionStatus.Invalid);
        return new SessionState(row.IsLocked ? SessionStatus.Locked : SessionStatus.Active, row.TenantId, row.IdleLockMinutes);
    }

    public async Task<SignInOutcome> UnlockAsync(string sessionKey, long userId, string password, RequestInfo request, CancellationToken ct = default)
    {
        var credential = await db.ResultAsync<CredentialRow>("dbo.usp_Auth_Credential_Get", new { UserId = userId }, ct);
        string identifier = $"user:{userId}";

        if (await BlockedAsync(userId, identifier, request, ct) is { } blocked) return blocked;
        if (credential.PasswordHash is null || !PasswordHasher.Verify(password, credential.PasswordHash))
            return await FailAsync(userId, identifier, AttemptType.Password, AttemptFailure.WrongSecret, request, ct);

        await RegisterAsync(userId, identifier, AttemptType.Password, true, null, request, ct);
        var unlocked = await db.ResultAsync<ProcResult>("dbo.usp_Auth_Session_Unlock",
            new { SessionKeyHash = SecureTokens.SessionKeyHash(sessionKey) }, ct);
        return new SignInOutcome(unlocked.Succeeded ? SignInStatus.Success : SignInStatus.InvalidCredentials, userId);
    }

    public Task LockAsync(string sessionKey, CancellationToken ct = default) =>
        db.ResultAsync<ProcResult>("dbo.usp_Auth_Session_Lock", new { SessionKeyHash = SecureTokens.SessionKeyHash(sessionKey) }, ct);

    public Task SignOutAsync(string sessionKey, CancellationToken ct = default) =>
        db.ResultAsync<ProcResult>("dbo.usp_Auth_Session_End",
            new { SessionKeyHash = SecureTokens.SessionKeyHash(sessionKey), UserId = (long?)null, EndReason = (byte)SessionEndReason.SignedOut }, ct);

    private async Task<SignInOutcome?> BlockedAsync(long? userId, string identifier, RequestInfo request, CancellationToken ct)
    {
        var block = await db.ResultAsync<BlockRow>("dbo.usp_Auth_Security_CheckBlock",
            new { UserId = userId, Identifier = identifier, request.IpAddress }, ct);
        return block.IsBlocked ? Locked(block.BlockedUntilUtc) : null;
    }

    private async Task<SignInOutcome> FailAsync(long? userId, string identifier, AttemptType type, AttemptFailure reason, RequestInfo request, CancellationToken ct)
    {
        var result = await RegisterAsync(userId, identifier, type, false, reason, request, ct);
        return result.IsBlocked ? Locked(result.BlockedUntilUtc) : new SignInOutcome(SignInStatus.InvalidCredentials);
    }

    private Task<BlockRow> RegisterAsync(long? userId, string identifier, AttemptType type, bool success, AttemptFailure? reason, RequestInfo request, CancellationToken ct) =>
        db.ResultAsync<BlockRow>("dbo.usp_Auth_Attempt_Register", new
        {
            UserId = userId,
            TenantId = (long?)null,
            Identifier = identifier,
            AttemptType = (byte)type,
            IsSuccess = success,
            FailureReason = (byte?)reason,
            request.IpAddress,
            request.UserAgent,
        }, ct);

    private static SignInOutcome Locked(DateTime? untilUtc) =>
        new(SignInStatus.Locked, LockedUntil: untilUtc is { } u ? new DateTimeOffset(DateTime.SpecifyKind(u, DateTimeKind.Utc)) : null);
}
