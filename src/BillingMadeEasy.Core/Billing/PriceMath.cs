namespace BillingMadeEasy.Core.Billing;

public sealed record PriceSplit(decimal Taxable, decimal Tax, decimal Total);

public sealed record Margin(decimal Profit, decimal? MarkupPercent, decimal? MarginPercent);

/// <summary>
/// The arithmetic behind a price field. A price entered "including GST" is split back into its
/// taxable value and tax; one entered "before GST" has tax added. Rounded to paise.
/// </summary>
public static class PriceMath
{
    public static PriceSplit Split(decimal price, decimal ratePercent, bool inclusive)
    {
        if (ratePercent < 0) throw new ArgumentOutOfRangeException(nameof(ratePercent));
        if (inclusive)
        {
            decimal taxable = Math.Round(price * 100m / (100m + ratePercent), 2, MidpointRounding.AwayFromZero);
            return new PriceSplit(taxable, price - taxable, price);
        }
        decimal tax = Math.Round(price * ratePercent / 100m, 2, MidpointRounding.AwayFromZero);
        return new PriceSplit(price, tax, price + tax);
    }

    /// <summary>Profit on the taxable value. Markup is on cost; margin is on the selling price.</summary>
    public static Margin MarginOf(decimal sellingTaxable, decimal cost) =>
        new(sellingTaxable - cost,
            cost == 0 ? null : Math.Round((sellingTaxable - cost) / cost * 100m, 1),
            sellingTaxable == 0 ? null : Math.Round((sellingTaxable - cost) / sellingTaxable * 100m, 1));
}
