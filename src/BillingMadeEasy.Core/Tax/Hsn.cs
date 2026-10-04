namespace BillingMadeEasy.Core.Tax;

/// <summary>
/// HSN (goods) and SAC (services) codes. GST portals and e-invoices check these; a wrong length or
/// a SAC on goods is a rejected return line. Goods: 4, 6 or 8 digits. Services: 6 digits from 99.
/// </summary>
public static class Hsn
{
    public static string? Normalize(string? code) =>
        string.IsNullOrWhiteSpace(code) ? null : new string(code.Where(char.IsDigit).ToArray());

    /// <summary>What's wrong with the code, in words, or null when it's acceptable.</summary>
    public static string? Problem(string? code, bool isService)
    {
        string? c = Normalize(code);
        if (c is null) return null;
        if (isService)
        {
            if (!c.StartsWith("99", StringComparison.Ordinal)) return "Service codes (SAC) start with 99, e.g. 998361.";
            if (c.Length != 6) return "A SAC is 6 digits, e.g. 998361.";
            return null;
        }
        if (c.StartsWith("99", StringComparison.Ordinal) && c.Length == 6) return "Codes starting 99 are for services. Goods use an HSN code.";
        if (c.Length is not (4 or 6 or 8)) return "An HSN code is 4, 6 or 8 digits.";
        return null;
    }
}
