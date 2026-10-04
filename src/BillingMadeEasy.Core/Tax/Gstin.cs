using System.Text.RegularExpressions;

namespace BillingMadeEasy.Core.Tax;

/// <summary>
/// GSTIN structure and checksum (mod-36 Luhn variant used by GSTN).
/// The first two digits are the state code, which decides CGST+SGST versus IGST on an invoice.
/// </summary>
public static partial class Gstin
{
    private const string Charset = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";

    [GeneratedRegex("^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$")]
    private static partial Regex Shape();

    public static string Normalize(string? value) =>
        (value ?? string.Empty).Trim().Replace(" ", string.Empty).ToUpperInvariant();

    public static GstinCheck Check(string? value)
    {
        string gstin = Normalize(value);
        if (gstin.Length == 0) return GstinCheck.Empty;
        if (gstin.Length != 15) return GstinCheck.WrongLength;
        if (!Shape().IsMatch(gstin)) return GstinCheck.WrongFormat;

        if (StateCodes.Name(gstin[..2]) is null) return GstinCheck.UnknownState;

        return gstin[14] == CheckCharacter(gstin.AsSpan(0, 14)) ? GstinCheck.Valid : GstinCheck.ChecksumMismatch;
    }

    public static bool IsValid(string? value) => Check(value) == GstinCheck.Valid;

    public static string StateCode(string gstin) => Normalize(gstin)[..2];

    public static string Pan(string gstin) => Normalize(gstin).Substring(2, 10);

    /// <summary>True when supplier and recipient share a state: CGST + SGST. Otherwise IGST.</summary>
    public static bool IsIntraState(string supplierStateCode, string placeOfSupplyStateCode) =>
        string.Equals(supplierStateCode, placeOfSupplyStateCode, StringComparison.Ordinal);

    internal static char CheckCharacter(ReadOnlySpan<char> first14)
    {
        int sum = 0;
        for (int i = 0; i < first14.Length; i++)
        {
            int value = Charset.IndexOf(first14[i]);
            int product = value * (i % 2 == 0 ? 1 : 2);
            sum += product / 36 + product % 36;
        }
        return Charset[(36 - sum % 36) % 36];
    }
}

public enum GstinCheck
{
    Valid,
    Empty,
    WrongLength,
    WrongFormat,
    UnknownState,
    ChecksumMismatch,
}
