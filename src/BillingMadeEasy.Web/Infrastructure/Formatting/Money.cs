using System.Globalization;

namespace BillingMadeEasy.Web.Infrastructure.Formatting;

/// <summary>Rupees the Indian way: ₹1,25,000.50 (lakh grouping).</summary>
public static class Money
{
    private static readonly CultureInfo India = CultureInfo.GetCultureInfo("en-IN");

    public static string Inr(decimal? amount, string empty = "—") =>
        amount is null ? empty : "₹" + amount.Value.ToString(amount.Value % 1 == 0 ? "#,##,##0" : "#,##,##0.00", India);

    public static string Plain(decimal? amount) =>
        amount is null ? "" : amount.Value.ToString(amount.Value % 1 == 0 ? "0" : "0.00", CultureInfo.InvariantCulture);
}
