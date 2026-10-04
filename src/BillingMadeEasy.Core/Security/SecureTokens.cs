using System.Security.Cryptography;
using System.Text;

namespace BillingMadeEasy.Core.Security;

/// <summary>
/// One-time codes, session keys and remember-me tokens. Only the salted SHA-256 of a token is
/// ever sent to SQL; the raw value lives in the cookie or the email and nowhere else.
/// </summary>
public static class SecureTokens
{
    /// <summary>Numeric OTP of <paramref name="digits"/> length. <see cref="RandomNumberGenerator.GetInt32(int, int)"/> is unbiased.</summary>
    public static string NumericCode(int digits = 6)
    {
        ArgumentOutOfRangeException.ThrowIfLessThan(digits, 4);
        ArgumentOutOfRangeException.ThrowIfGreaterThan(digits, 9);
        int max = (int)Math.Pow(10, digits);
        return RandomNumberGenerator.GetInt32(0, max).ToString(new string('0', digits));
    }

    /// <summary>URL-safe random token, 256 bits by default.</summary>
    public static string UrlToken(int bytes = 32) =>
        Convert.ToBase64String(RandomNumberGenerator.GetBytes(bytes))
            .TrimEnd('=').Replace('+', '-').Replace('/', '_');

    /// <summary>The 32-byte key that identifies a session row (<c>tbl_UserSessions.SessionKeyHash</c>).
    /// The raw key lives only inside the encrypted auth cookie.</summary>
    public static byte[] SessionKeyHash(string sessionKey)
    {
        ArgumentException.ThrowIfNullOrEmpty(sessionKey);
        return SHA256.HashData(Encoding.UTF8.GetBytes(sessionKey));
    }

    public static string NewSalt() => Convert.ToBase64String(RandomNumberGenerator.GetBytes(16));

    /// <summary>Hex SHA-256 of salt + token. Check the encoding against <c>ClassSecurity</c> before
    /// pointing it at existing <c>tbl_AuthTokens</c> rows; new rows written through here are consistent.</summary>
    public static string Hash(string token, string salt)
    {
        byte[] digest = SHA256.HashData(Encoding.UTF8.GetBytes(salt + token));
        return Convert.ToHexString(digest);
    }
}
