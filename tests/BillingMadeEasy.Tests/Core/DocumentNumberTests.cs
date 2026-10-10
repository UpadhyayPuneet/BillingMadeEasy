using BillingMadeEasy.Core.Billing;

namespace BillingMadeEasy.Tests.Core;

public sealed class DocumentNumberTests
{
    [Theory]
    [InlineData("INV", null, "-", 2, 2026, 7, 4, "INV-26-27-0007")]
    [InlineData("INV", null, "/", 1, 2026, 12, 3, "INV/2026-27/012")]
    [InlineData(null, null, "-", 2, 2026, 1, 4, "26-27-0001")]
    [InlineData("CN", "MUM", "-", 3, 2026, 5, 2, "CN-2026-05-MUM")]
    [InlineData("INV", null, "-", 0, 2026, 42, 4, "INV-0042")]
    [InlineData("INV", null, "", 2, 2026, 3, 4, "INV26-270003")]
    [InlineData("INV", null, "-", 2, 2099, 1, 4, "INV-99-00-0001")]
    public void Formats_like_the_database(string? prefix, string? suffix, string sep, byte year, int fy, long seq, int pad, string expected) =>
        Assert.Equal(expected, DocumentNumber.Format(prefix, suffix, sep, year, fy, seq, pad));

    [Fact]
    public void A_run_that_outgrows_its_padding_widens_instead_of_wrapping()
    {
        Assert.Equal("INV-26-27-9999", DocumentNumber.Format("INV", null, "-", 2, 2026, 9999, 4));
        Assert.Equal("INV-26-27-10000", DocumentNumber.Format("INV", null, "-", 2, 2026, 10000, 4));
    }

    [Theory]
    [InlineData(2027, 3, 31, 2026)]
    [InlineData(2026, 4, 1, 2026)]
    [InlineData(2027, 1, 15, 2026)]
    public void Financial_year_runs_April_to_March(int y, int m, int d, int expected) =>
        Assert.Equal(expected, DocumentNumber.FinancialYear(new DateOnly(y, m, d)));
}
