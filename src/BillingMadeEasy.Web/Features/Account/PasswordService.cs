using BillingMadeEasy.Core;
using BillingMadeEasy.Core.Security;
using BillingMadeEasy.Data;
using BillingMadeEasy.Web.Infrastructure.Auth;
using BillingMadeEasy.Web.Infrastructure.Email;
using BillingMadeEasy.Web.Infrastructure.Settings;

namespace BillingMadeEasy.Web.Features.Account;

public enum PasswordChangeReason : byte
{
    SelfChange = 1,
    Reset = 2,
    AdminSet = 3,
    FirstSet = 4,
}

/// <summary>
/// Forgotten passwords, resets and changes. The same rules apply on every path: the business's
/// minimum length, no recent password again, nothing built from the person's name or email.
/// </summary>
public sealed class PasswordService(IDb db, AccountTokens tokens, EmailService email, SettingsReader settings, ILogger<PasswordService> log)
{
    private sealed class IdentityRow : ProcResult
    {
        public long UserId { get; init; }
        public Guid PublicId { get; init; }
        public string FullName { get; init; } = "";
    }

    private sealed class CredentialRow : ProcResult
    {
        public string? PasswordHash { get; init; }
        public string Email { get; init; } = "";
        public string FullName { get; init; } = "";
    }

    private sealed class CanSendRow : ProcResult;

    private sealed class HistoryRow
    {
        public string PasswordHash { get; init; } = "";
    }

    /// <summary>
    /// Sends a reset link if the identifier matches an active account. Says nothing either way:
    /// the caller shows the same message whether or not anyone matched.
    /// </summary>
    public async Task RequestResetAsync(string identifier, HttpRequest request, RequestInfo info, CancellationToken ct)
    {
        identifier = identifier.Trim();
        var identity = await db.ResultAsync<IdentityRow>("dbo.usp_Auth_Identity_Resolve", new { Identifier = identifier }, ct);
        if (!identity.Succeeded) return;

        var credential = await db.ResultAsync<CredentialRow>("dbo.usp_Auth_Credential_Get", new { identity.UserId }, ct);

        // A link sent minutes ago still works; sending another only buries the first.
        int reuseMinutes = await settings.GetIntAsync(null, "Security.ResetReuseWindowMinutes", 15);
        if (await tokens.LiveIssuedAtAsync(identity.UserId, TokenType.PasswordReset, ct) is { } issued
            && DateTime.UtcNow - DateTime.SpecifyKind(issued, DateTimeKind.Utc) < TimeSpan.FromMinutes(reuseMinutes))
            return;

        var allowed = await db.ResultAsync<CanSendRow>("dbo.usp_Comm_CanSend", new
        {
            TemplateCode = "AUTH_PASSWORD_RESET",
            identity.UserId,
            info.IpAddress,
            AttemptType = (byte)AttemptType.Reset,
        }, ct);
        if (!allowed.Succeeded)
        {
            log.LogWarning("Reset email suppressed for user {UserId}: {Reason}", identity.UserId, allowed.ResultMessage);
            return;
        }

        var token = await tokens.IssueAsync(identity.UserId, null, TokenType.PasswordReset, credential.Email, info.IpAddress, ct);
        if (token is null) return;

        string link = email.PublicUrl(request, $"/Account/Reset?u={identity.PublicId:N}&t={Uri.EscapeDataString(token.Token)}");
        await email.SendTemplateAsync("AUTH_PASSWORD_RESET", credential.Email, credential.FullName, new Dictionary<string, string>
        {
            ["FullName"] = credential.FullName,
            ["ResetLink"] = link,
            ["ValidityMinutes"] = token.ValidityMinutes.ToString(),
            ["Preheader"] = "Use this link to choose a new password",
        }, null, identity.UserId, "User", identity.UserId, ct);
    }

    public Task<int> MinLengthAsync(long? tenantId, CancellationToken ct) =>
        settings.GetIntAsync(tenantId, "Security.PasswordMinLength", 10);

    /// <summary>The first rule the new password breaks, in words for the person, or null if it's fine.</summary>
    public async Task<string?> CheckAsync(long userId, long? tenantId, string password, string confirm, string emailAddress, string fullName, CancellationToken ct)
    {
        int min = await MinLengthAsync(tenantId, ct);
        if (password.Length < min) return $"Use at least {min} characters. A short sentence works well.";
        if (password != confirm) return "The two passwords don't match.";
        if (ContainsIdentity(password, emailAddress, fullName)) return "Don't use your name or email in your password.";

        var history = await db.ListAsync<HistoryRow>("dbo.usp_Auth_PasswordHistory_Get", new { UserId = userId, TenantId = tenantId }, ct);
        if (history.Any(h => PasswordHasher.Verify(password, h.PasswordHash)))
            return "You've used that password recently. Choose a different one.";
        return null;
    }

    /// <summary>Whether <paramref name="password"/> is this person's current password.</summary>
    public async Task<bool> VerifyCurrentAsync(long userId, string password, CancellationToken ct)
    {
        var credential = await db.ResultAsync<CredentialRow>("dbo.usp_Auth_Credential_Get", new { UserId = userId }, ct);
        return credential.PasswordHash is not null && PasswordHasher.Verify(password, credential.PasswordHash);
    }

    /// <summary>Stores the new password. Every existing session ends (the security stamp changes).</summary>
    public async Task<bool> SetAsync(long userId, string password, PasswordChangeReason reason, long? tenantId, string? ip, CancellationToken ct)
    {
        var result = await db.ResultAsync<ProcResult>("dbo.usp_Auth_Password_Set", new
        {
            UserId = userId,
            NewPasswordHash = PasswordHasher.Hash(password),
            ChangedByUserId = userId,
            ChangeReason = (byte)reason,
            TenantId = tenantId,
            IpAddress = ip,
            EndOtherSessions = true,
        }, ct);
        return result.Succeeded;
    }

    private static bool ContainsIdentity(string password, string emailAddress, string fullName)
    {
        string p = password.ToLowerInvariant();
        string local = emailAddress.Split('@')[0].ToLowerInvariant();
        return (local.Length >= 4 && p.Contains(local))
               || fullName.Split(' ', StringSplitOptions.RemoveEmptyEntries).Any(n => n.Length >= 4 && p.Contains(n.ToLowerInvariant()));
    }
}
