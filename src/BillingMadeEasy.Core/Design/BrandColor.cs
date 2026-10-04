using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace BillingMadeEasy.Core.Design;

/// <summary>A named brand colour. Stored as JSON; older plain lists ("#E63946, #1D3557") still read.</summary>
public sealed partial record BrandColor(string Name, string Hex)
{
    [GeneratedRegex("^#?([0-9A-Fa-f]{6}|[0-9A-Fa-f]{3})$")]
    private static partial Regex HexPattern();

    [GeneratedRegex("#?[0-9A-Fa-f]{6}\\b|#[0-9A-Fa-f]{3}\\b")]
    private static partial Regex AnyHex();

    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    /// <summary>"e63946", "#E63946", "#e39" → "#E63946"; null when it isn't a colour.</summary>
    public static string? NormalizeHex(string? value)
    {
        var m = HexPattern().Match((value ?? "").Trim());
        if (!m.Success) return null;
        string h = m.Groups[1].Value.ToUpperInvariant();
        if (h.Length == 3) h = string.Concat(h.Select(c => $"{c}{c}"));
        return "#" + h;
    }

    public static IReadOnlyList<BrandColor> Parse(string? stored)
    {
        if (string.IsNullOrWhiteSpace(stored)) return [];
        if (stored.TrimStart().StartsWith('['))
        {
            try
            {
                return (JsonSerializer.Deserialize<List<BrandColor>>(stored, Json) ?? [])
                    .Select(c => NormalizeHex(c.Hex) is { } hex ? c with { Hex = hex, Name = c.Name?.Trim() ?? "" } : null)
                    .OfType<BrandColor>().ToList();
            }
            catch (JsonException) { /* fall through to the plain reading */ }
        }
        return AnyHex().Matches(stored).Select((m, i) => new BrandColor($"Colour {i + 1}", NormalizeHex(m.Value)!)).ToList();
    }

    public static string? Serialize(IEnumerable<BrandColor> colors)
    {
        var list = colors.ToList();
        return list.Count == 0 ? null : JsonSerializer.Serialize(list, Json);
    }

    /// <summary>WCAG relative luminance.</summary>
    public double Luminance
    {
        get
        {
            static double Channel(int v)
            {
                double c = v / 255.0;
                return c <= 0.03928 ? c / 12.92 : Math.Pow((c + 0.055) / 1.055, 2.4);
            }
            int rgb = int.Parse(Hex[1..], NumberStyles.HexNumber, CultureInfo.InvariantCulture);
            return 0.2126 * Channel(rgb >> 16 & 0xFF) + 0.7152 * Channel(rgb >> 8 & 0xFF) + 0.0722 * Channel(rgb & 0xFF);
        }
    }

    public static double Contrast(double l1, double l2) => (Math.Max(l1, l2) + 0.05) / (Math.Min(l1, l2) + 0.05);

    /// <summary>White or black, whichever reads better on this colour, and how well (4.5+ passes for body text).</summary>
    public (string Text, double Ratio) ReadableText
    {
        get
        {
            double onWhite = Contrast(Luminance, 1.0), onBlack = Contrast(Luminance, 0.0);
            return onWhite >= onBlack ? ("#FFFFFF", onWhite) : ("#000000", onBlack);
        }
    }

    public string Rgb
    {
        get
        {
            int rgb = int.Parse(Hex[1..], NumberStyles.HexNumber, CultureInfo.InvariantCulture);
            return $"{rgb >> 16 & 0xFF}, {rgb >> 8 & 0xFF}, {rgb & 0xFF}";
        }
    }
}
