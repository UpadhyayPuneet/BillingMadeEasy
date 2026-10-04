namespace BillingMadeEasy.Web.Infrastructure.Formatting;

public static class Phone
{
    /// <summary>"+91 98765-43210", "098765 43210" → "9876543210". Null when empty.</summary>
    public static string? NormalizeIndianMobile(string? input)
    {
        if (string.IsNullOrWhiteSpace(input)) return null;
        string digits = new(input.Where(char.IsDigit).ToArray());
        return digits.Length >= 10 ? digits[^10..] : digits;
    }

    public static bool IsIndianMobile(string? normalized) =>
        normalized is { Length: 10 } && normalized[0] is >= '6' and <= '9';
}
