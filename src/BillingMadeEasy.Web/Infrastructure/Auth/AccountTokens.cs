using System.Security.Cryptography;
using System.Text;
using BillingMadeEasy.Core;
using BillingMadeEasy.Core.Security;
using BillingMadeEasy.Data;

namespace BillingMadeEasy.Web.Infrastructure.Auth;

public enum TokenType : byte
{
    Otp = 1,
    PasswordReset = 2,
    Invite = 3,
}

public sealed record IssuedToken(string Token, DateTime ExpiresAtUtc, int ValidityMinutes);

/// <summary>
/// One-time tokens in tbl_AuthTokens. The raw token goes in the link and nowhere else; SQL keeps
/// a 16-byte salt and SHA-256(salt ‖ token). Validation counts attempts under a row lock.
/// Links issued by the Web Forms app hash differently and won't validate here; resending replaces them.
/// </summary>
public sealed class AccountTokens(IDb db)
{
    private sealed class IssueRow : ProcResult
    {
        public DateTime ExpiresAtUtc { get; init; }
        public int ValidityMinutes { get; init; }
        public int RetryAfterSeconds { get; init; }
    }

    private sealed class ActiveRow : ProcResult
    {
        public byte[]? TokenSalt { get; init; }
        public DateTime? IssuedAtUtc { get; init; }
    }

    public sealed class UserRow : ProcResult
    {
        public long UserId { get; init; }
        public Guid PublicId { get; init; }
        public string FullName { get; init; } = "";
        public string Email { get; init; } = "";
        public byte Status { get; init; }
        public bool IsActive { get; init; }
    }

    public async Task<IssuedToken?> IssueAsync(long userId, long? tenantId, TokenType type, string sentTo, string? ip, CancellationToken ct)
    {
        string token = SecureTokens.UrlToken();
        byte[] salt = RandomNumberGenerator.GetBytes(16);
        var row = await db.ResultAsync<IssueRow>("dbo.usp_Auth_Token_Issue", new
        {
            UserId = userId,
            TenantId = tenantId,
            TokenType = (byte)type,
            TokenSalt = salt,
            TokenHash = Hash(salt, token),
            DeliveryChannel = (byte)1,
            SentTo = sentTo,
            RequestIp = ip,
            IsResend = false,
        }, ct);
        return row.Succeeded ? new IssuedToken(token, row.ExpiresAtUtc, row.ValidityMinutes) : null;
    }

    /// <summary>Consumes the token if it matches. False for wrong, expired, used or exhausted.</summary>
    public async Task<bool> ConsumeAsync(long userId, TokenType type, string token, CancellationToken ct)
    {
        var active = await db.SingleAsync<ActiveRow>("dbo.usp_Auth_Token_GetActive", new { UserId = userId, TokenType = (byte)type }, ct);
        if (active is null || !active.Succeeded || active.TokenSalt is null) return false;

        var result = await db.ResultAsync<ProcResult>("dbo.usp_Auth_Token_Validate",
            new { UserId = userId, TokenType = (byte)type, TokenHash = Hash(active.TokenSalt, token) }, ct);
        return result.Succeeded;
    }

    /// <summary>Checks a token is live without spending an attempt (for showing the welcome page).</summary>
    public async Task<bool> IsLiveAsync(long userId, TokenType type, CancellationToken ct)
    {
        var active = await db.SingleAsync<ActiveRow>("dbo.usp_Auth_Token_GetActive", new { UserId = userId, TokenType = (byte)type }, ct);
        return active is { Succeeded: true, TokenSalt: not null };
    }

    /// <summary>When the live token of this type was issued, or null if there isn't one.</summary>
    public async Task<DateTime?> LiveIssuedAtAsync(long userId, TokenType type, CancellationToken ct)
    {
        var active = await db.SingleAsync<ActiveRow>("dbo.usp_Auth_Token_GetActive", new { UserId = userId, TokenType = (byte)type }, ct);
        return active is { Succeeded: true, TokenSalt: not null } ? active.IssuedAtUtc : null;
    }

    public Task<UserRow?> UserByPublicIdAsync(Guid publicId, CancellationToken ct) =>
        db.SingleAsync<UserRow>("dbo.usp_Auth_User_GetByPublicId", new { PublicId = publicId }, ct);

    private static byte[] Hash(byte[] salt, string token)
    {
        byte[] tokenBytes = Encoding.UTF8.GetBytes(token);
        byte[] input = new byte[salt.Length + tokenBytes.Length];
        salt.CopyTo(input, 0);
        tokenBytes.CopyTo(input, salt.Length);
        return SHA256.HashData(input);
    }
}
