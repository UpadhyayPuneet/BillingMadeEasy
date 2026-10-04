using System.Security.Cryptography;
using BillingMadeEasy.Core.Security;

namespace BillingMadeEasy.Tests.Core;

public class PasswordHasherTests
{
    [Fact]
    public void Hash_matches_the_web_forms_format()
    {
        string hash = PasswordHasher.Hash("correct horse battery staple");

        // 21 prefix + 24 salt + 1 separator + 44 hash = 90, as verified against the Web Forms build.
        Assert.StartsWith("PBKDF2$SHA256$210000$", hash);
        Assert.Equal(90, hash.Length);
    }

    [Fact]
    public void Verify_accepts_the_right_secret_and_rejects_others()
    {
        string hash = PasswordHasher.Hash("Secret#123");

        Assert.True(PasswordHasher.Verify("Secret#123", hash));
        Assert.False(PasswordHasher.Verify("secret#123", hash));
        Assert.False(PasswordHasher.Verify("", hash));
    }

    [Fact]
    public void Verify_reads_the_iteration_count_from_the_string()
    {
        // A hash written with a lower work factor (as an older build would) still verifies, and is flagged for upgrade.
        byte[] salt = RandomNumberGenerator.GetBytes(16);
        byte[] derived = Rfc2898DeriveBytes.Pbkdf2("1234", salt, 1000, HashAlgorithmName.SHA256, 32);
        string legacy = $"PBKDF2$SHA256$1000${Convert.ToBase64String(salt)}${Convert.ToBase64String(derived)}";

        Assert.True(PasswordHasher.Verify("1234", legacy));
        Assert.True(PasswordHasher.NeedsRehash(legacy));
        Assert.False(PasswordHasher.NeedsRehash(PasswordHasher.Hash("1234")));
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("plain-text")]
    [InlineData("PBKDF2$SHA1$1000$AAAA$AAAA")]
    [InlineData("PBKDF2$SHA256$abc$AAAA$AAAA")]
    [InlineData("PBKDF2$SHA256$1000$not base64!$AAAA")]
    public void Verify_rejects_malformed_hashes_without_throwing(string? stored) =>
        Assert.False(PasswordHasher.Verify("anything", stored));
}

public class SecureTokenTests
{
    [Theory]
    [InlineData(4)]
    [InlineData(6)]
    [InlineData(8)]
    public void NumericCode_has_exact_length_and_only_digits(int digits)
    {
        for (int i = 0; i < 200; i++)
        {
            string code = SecureTokens.NumericCode(digits);
            Assert.Equal(digits, code.Length);
            Assert.All(code, c => Assert.InRange(c, '0', '9'));
        }
    }

    [Fact]
    public void UrlToken_is_url_safe_and_unique()
    {
        var tokens = Enumerable.Range(0, 100).Select(_ => SecureTokens.UrlToken()).ToHashSet();
        Assert.Equal(100, tokens.Count);
        Assert.All(tokens, t => Assert.DoesNotContain(t, c => c is '+' or '/' or '='));
    }

    [Fact]
    public void Hash_depends_on_salt()
    {
        Assert.Equal(SecureTokens.Hash("abc", "s1"), SecureTokens.Hash("abc", "s1"));
        Assert.NotEqual(SecureTokens.Hash("abc", "s1"), SecureTokens.Hash("abc", "s2"));
    }
}
