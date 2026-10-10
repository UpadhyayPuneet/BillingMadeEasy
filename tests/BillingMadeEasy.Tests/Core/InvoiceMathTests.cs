using BillingMadeEasy.Core.Billing;

namespace BillingMadeEasy.Tests.Core;

public sealed class InvoiceMathTests
{
    [Fact]
    public void Same_state_splits_GST_into_equal_CGST_and_SGST()
    {
        var a = InvoiceMath.Line(new LineInput(4, 2500m, TaxRatePercent: 18), interState: false);
        Assert.Equal((10000m, 900m, 900m, 0m, 11800m), (a.Taxable, a.Cgst, a.Sgst, a.Igst, a.Total));
    }

    [Fact]
    public void Another_state_is_IGST()
    {
        var a = InvoiceMath.Line(new LineInput(4, 2500m, TaxRatePercent: 18), interState: true);
        Assert.Equal((10000m, 0m, 0m, 1800m, 11800m), (a.Taxable, a.Cgst, a.Sgst, a.Igst, a.Total));
    }

    [Theory]
    [InlineData(false, 3813.56, 343.22, 343.22, 0)]
    [InlineData(true, 3813.56, 0, 0, 686.44)]
    public void A_price_including_GST_is_exactly_what_the_customer_pays(bool inter, decimal taxable, decimal cgst, decimal sgst, decimal igst)
    {
        var a = InvoiceMath.Line(new LineInput(1, 4500m, RateIncludesTax: true, TaxRatePercent: 18), inter);
        Assert.Equal((taxable, cgst, sgst, igst, 4500m), (a.Taxable, a.Cgst, a.Sgst, a.Igst, a.Total));
    }

    [Fact]
    public void Halves_stay_equal_even_when_the_paise_are_odd()
    {
        // 99.99 at 5%: tax 4.9995. Each half rounds once to 2.50, so CGST and SGST match.
        var a = InvoiceMath.Line(new LineInput(1, 99.99m, TaxRatePercent: 5), interState: false);
        Assert.Equal(a.Cgst, a.Sgst);
        Assert.Equal(2.50m, a.Cgst);
    }

    [Fact]
    public void Discount_comes_off_before_tax()
    {
        var a = InvoiceMath.Line(new LineInput(1, 10000m, DiscountPercent: 10, TaxRatePercent: 18), interState: true);
        Assert.Equal((10000m, 1000m, 9000m, 1620m, 10620m), (a.Gross, a.Discount, a.Taxable, a.Igst, a.Total));
    }

    [Fact]
    public void Composition_and_pure_agent_carry_no_tax()
    {
        var composition = InvoiceMath.Compute([new LineInput(2, 500m, TaxRatePercent: 18)], interState: false, roundToRupee: false, noTax: true);
        Assert.Equal((1000m, 0m, 1000m), (composition.Taxable, composition.Tax, composition.GrandTotal));

        var withFee = InvoiceMath.Compute(
            [new LineInput(1, 10000m, TaxRatePercent: 18, HsnSacCode: "998231"), new LineInput(1, 1500m, TaxRatePercent: 18, IsPureAgent: true)],
            interState: false, roundToRupee: false);
        Assert.Equal((10000m, 1800m, 1500m, 13300m), (withFee.Taxable, withFee.Tax, withFee.Reimbursements, withFee.GrandTotal));
        Assert.Single(withFee.TaxSummary);
    }

    [Theory]
    [InlineData(100.42, 100, -0.42)]
    [InlineData(100.50, 101, 0.50)]
    [InlineData(100.00, 100, 0)]
    public void Round_off_is_to_the_nearest_rupee(decimal before, decimal grand, decimal roundOff)
    {
        var t = InvoiceMath.Compute([new LineInput(1, before)], interState: false, roundToRupee: true);
        Assert.Equal((grand, roundOff), (t.GrandTotal, t.RoundOff));
    }

    [Fact]
    public void Tax_summary_groups_by_HSN_and_rate()
    {
        var t = InvoiceMath.Compute(
        [
            new LineInput(2, 4500m, TaxRatePercent: 18, HsnSacCode: "40111010"),
            new LineInput(1, 4000m, TaxRatePercent: 18, HsnSacCode: "40111010"),
            new LineInput(1, 300m, TaxRatePercent: 5, HsnSacCode: "40131010"),
        ], interState: false, roundToRupee: true);

        Assert.Equal(2, t.TaxSummary.Count);
        var tyres = t.TaxSummary[0];
        Assert.Equal((13000m, 1170m, 1170m), (tyres.Taxable, tyres.Cgst, tyres.Sgst));
        Assert.Equal(t.Tax, t.TaxSummary.Sum(r => r.Tax));
    }

    [Theory]
    [InlineData(4500, "Rupees Four Thousand Five Hundred Only")]
    [InlineData(100000, "Rupees One Lakh Only")]
    [InlineData(12345678.90, "Rupees One Crore Twenty Three Lakh Forty Five Thousand Six Hundred Seventy Eight and Ninety Paise Only")]
    [InlineData(0.5, "Rupees Zero and Fifty Paise Only")]
    [InlineData(1180, "Rupees One Thousand One Hundred Eighty Only")]
    public void Amounts_read_the_Indian_way(decimal amount, string words) => Assert.Equal(words, AmountInWords.Rupees(amount));

    [Theory]
    [InlineData("27", "27", false)]
    [InlineData("27", "29", true)]
    [InlineData("27", "96", true)]
    [InlineData("27", null, false)]
    public void Place_of_supply_decides_the_tax(string supplier, string? place, bool inter) =>
        Assert.Equal(inter, InvoiceMath.IsInterState(supplier, place));
}
