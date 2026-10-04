using BillingMadeEasy.Core.Billing;
using BillingMadeEasy.Core.Tax;

namespace BillingMadeEasy.Tests.Core;

public class CatalogMathTests
{
    [Fact]
    public void Exclusive_price_adds_tax()
    {
        Assert.Equal(new PriceSplit(1000m, 180m, 1180m), PriceMath.Split(1000m, 18m, inclusive: false));
    }

    [Fact]
    public void Inclusive_price_is_split_back_to_taxable_and_tax()
    {
        var split = PriceMath.Split(1180m, 18m, inclusive: true);
        Assert.Equal(1000m, split.Taxable);
        Assert.Equal(180m, split.Tax);

        var odd = PriceMath.Split(999m, 5m, inclusive: true);
        Assert.Equal(951.43m, odd.Taxable);
        Assert.Equal(999m, odd.Taxable + odd.Tax);
    }

    [Fact]
    public void Margin_and_markup_are_different_numbers()
    {
        var m = PriceMath.MarginOf(1250m, 1000m);
        Assert.Equal(250m, m.Profit);
        Assert.Equal(25.0m, m.MarkupPercent);
        Assert.Equal(20.0m, m.MarginPercent);
        Assert.Null(PriceMath.MarginOf(100m, 0m).MarkupPercent);
    }

    [Theory]
    [InlineData("4011", false, null)]
    [InlineData("4011 10 10", false, null)]
    [InlineData("40111", false, "An HSN code is 4, 6 or 8 digits.")]
    [InlineData("998361", false, "Codes starting 99 are for services. Goods use an HSN code.")]
    [InlineData("998361", true, null)]
    [InlineData("4011", true, "Service codes (SAC) start with 99, e.g. 998361.")]
    [InlineData("99836", true, "A SAC is 6 digits, e.g. 998361.")]
    [InlineData("", true, null)]
    public void Hsn_and_sac_rules(string code, bool service, string? problem) => Assert.Equal(problem, Hsn.Problem(code, service));
}
