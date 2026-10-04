using BillingMadeEasy.Core.Design;

namespace BillingMadeEasy.Tests.Core;

public class BrandColorTests
{
    [Theory]
    [InlineData("e63946", "#E63946")]
    [InlineData("#E63946", "#E63946")]
    [InlineData(" #e39 ", "#EE3399")]
    [InlineData("red", null)]
    [InlineData("#12345", null)]
    public void Hex_codes_are_normalised(string input, string? expected) => Assert.Equal(expected, BrandColor.NormalizeHex(input));

    [Fact]
    public void Json_round_trips_and_plain_lists_from_the_old_app_still_read()
    {
        var colors = new[] { new BrandColor("Primary", "#E63946"), new BrandColor("Ink", "#1D3557") };
        Assert.Equal(colors, BrandColor.Parse(BrandColor.Serialize(colors)));

        var legacy = BrandColor.Parse("#e63946, 1d3557");
        Assert.Equal(["#E63946", "#1D3557"], legacy.Select(c => c.Hex));
    }

    [Fact]
    public void Readable_text_follows_wcag_contrast()
    {
        Assert.Equal("#FFFFFF", new BrandColor("Navy", "#1D3557").ReadableText.Text);
        Assert.Equal("#000000", new BrandColor("Yellow", "#FFB703").ReadableText.Text);
        Assert.Equal(21.0, BrandColor.Contrast(1.0, 0.0), 1);
        Assert.Equal("230, 57, 70", new BrandColor("Red", "#E63946").Rgb);
    }
}
