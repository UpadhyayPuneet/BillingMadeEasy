using System.Security.Cryptography;

namespace BillingMadeEasy.Core.Security;

/// <summary>
/// PBKDF2-SHA256 password and PIN hashing.
/// Format: <c>PBKDF2$SHA256${iterations}${base64 salt}${base64 hash}</c> — byte-identical to the
/// Web Forms <c>ClassSecurity.HashPassword</c>, so hashes already stored in <c>tbl_Users</c> keep working.
/// The work factor travels inside the string, so raising <see cref="CurrentIterations"/> upgrades
/// each user silently at their next sign-in (see <see cref="NeedsRehash"/>).
/// </summary>
public static class PasswordHasher
{
    public const int CurrentIterations = 210_000;
    private const int SaltBytes = 16;
    private const int HashBytes = 32;
    private const string Prefix = "PBKDF2";
    private const string Algorithm = "SHA256";

    public static string Hash(string secret)
    {
        ArgumentException.ThrowIfNullOrEmpty(secret);
        byte[] salt = RandomNumberGenerator.GetBytes(SaltBytes);
        byte[] hash = Rfc2898DeriveBytes.Pbkdf2(secret, salt, CurrentIterations, HashAlgorithmName.SHA256, HashBytes);
        return $"{Prefix}${Algorithm}${CurrentIterations}${Convert.ToBase64String(salt)}${Convert.ToBase64String(hash)}";
    }

    public static bool Verify(string secret, string? stored)
    {
        if (string.IsNullOrEmpty(secret) || !TryParse(stored, out int iterations, out byte[] salt, out byte[] expected))
            return false;

        byte[] actual = Rfc2898DeriveBytes.Pbkdf2(secret, salt, iterations, HashAlgorithmName.SHA256, expected.Length);
        return CryptographicOperations.FixedTimeEquals(actual, expected);
    }

    /// <summary>True when a verified hash was produced with a weaker work factor than today's.</summary>
    public static bool NeedsRehash(string? stored) =>
        !TryParse(stored, out int iterations, out _, out _) || iterations < CurrentIterations;

    private static bool TryParse(string? stored, out int iterations, out byte[] salt, out byte[] hash)
    {
        iterations = 0;
        salt = hash = [];
        if (string.IsNullOrEmpty(stored)) return false;

        string[] parts = stored.Split('$');
        if (parts.Length != 5 || parts[0] != Prefix || parts[1] != Algorithm) return false;
        if (!int.TryParse(parts[2], out iterations) || iterations < 1) return false;

        try
        {
            salt = Convert.FromBase64String(parts[3]);
            hash = Convert.FromBase64String(parts[4]);
        }
        catch (FormatException)
        {
            return false;
        }
        return salt.Length > 0 && hash.Length > 0;
    }
}
