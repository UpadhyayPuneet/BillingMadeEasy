namespace BillingMadeEasy.Core.Billing;

/// <summary>One line as entered: what was sold, how many, at what rate.</summary>
public sealed record LineInput(
    decimal Quantity,
    decimal Rate,
    bool RateIncludesTax = false,
    decimal DiscountPercent = 0,
    decimal TaxRatePercent = 0,
    bool IsPureAgent = false,
    string? HsnSacCode = null);

/// <summary>A line with every amount the invoice prints, each rounded to paise.</summary>
public sealed record LineAmounts(
    decimal Gross,
    decimal Discount,
    decimal Taxable,
    decimal TaxRatePercent,
    decimal Cgst,
    decimal Sgst,
    decimal Igst,
    decimal Total,
    bool IsPureAgent,
    string? HsnSacCode)
{
    public decimal Tax => Cgst + Sgst + Igst;
}

/// <summary>Per HSN/SAC and rate: the tax summary printed under the lines.</summary>
public sealed record TaxSummaryRow(string? HsnSacCode, decimal RatePercent, decimal Taxable, decimal Cgst, decimal Sgst, decimal Igst)
{
    public decimal Tax => Cgst + Sgst + Igst;
}

public sealed record InvoiceTotals(
    IReadOnlyList<LineAmounts> Lines,
    decimal Gross,
    decimal Discount,
    decimal Taxable,
    decimal Cgst,
    decimal Sgst,
    decimal Igst,
    decimal Reimbursements,
    decimal BeforeRounding,
    decimal RoundOff,
    decimal GrandTotal,
    IReadOnlyList<TaxSummaryRow> TaxSummary)
{
    public decimal Tax => Cgst + Sgst + Igst;
}

/// <summary>
/// GST arithmetic for a sales document. Pure functions: the same input always gives the same
/// paise, on screen, in the database and on paper.
/// <list type="bullet">
/// <item>Same state as the supplier: CGST and SGST, always equal halves (each half rounded once).</item>
/// <item>Another state, or abroad: IGST.</item>
/// <item>A rate that includes tax: the customer pays exactly that; the tax is taken out of it.</item>
/// <item>Composition scheme: no tax is charged at all (a bill of supply).</item>
/// <item>Pure-agent reimbursements sit outside the taxable value and carry no tax.</item>
/// </list>
/// </summary>
public static class InvoiceMath
{
    public static decimal Round2(decimal value) => Math.Round(value, 2, MidpointRounding.AwayFromZero);

    public static LineAmounts Line(LineInput line, bool interState, bool noTax = false)
    {
        ArgumentOutOfRangeException.ThrowIfNegative(line.Quantity);
        ArgumentOutOfRangeException.ThrowIfNegative(line.Rate);
        if (line.DiscountPercent is < 0 or > 100) throw new ArgumentOutOfRangeException(nameof(line), "Discount must be 0–100%.");

        decimal rate = noTax || line.IsPureAgent ? 0 : Math.Max(0, line.TaxRatePercent);
        decimal gross = Round2(line.Quantity * line.Rate);
        decimal discount = Round2(gross * line.DiscountPercent / 100m);
        decimal net = gross - discount;

        decimal cgst = 0, sgst = 0, igst = 0, taxable;
        if (line.RateIncludesTax && rate > 0)
        {
            // The amount entered is what the customer pays; the tax inside it is carved out.
            decimal taxInside = net - net * 100m / (100m + rate);
            if (interState) igst = Round2(taxInside);
            else { cgst = Round2(taxInside / 2m); sgst = cgst; }
            taxable = net - cgst - sgst - igst;
        }
        else
        {
            taxable = net;
            if (interState) igst = Round2(taxable * rate / 100m);
            else { cgst = Round2(taxable * rate / 200m); sgst = cgst; }
        }

        // A rate entered "including tax" for an item that turns out to carry none is just the price.
        if (line.RateIncludesTax && rate == 0) taxable = net;

        return new LineAmounts(gross, discount, taxable, rate, cgst, sgst, igst, taxable + cgst + sgst + igst,
            line.IsPureAgent, string.IsNullOrWhiteSpace(line.HsnSacCode) ? null : line.HsnSacCode);
    }

    public static InvoiceTotals Compute(IEnumerable<LineInput> lines, bool interState, bool roundToRupee, bool noTax = false)
    {
        var amounts = lines.Select(l => Line(l, interState, noTax)).ToList();

        var supplies = amounts.Where(a => !a.IsPureAgent).ToList();
        decimal reimbursements = amounts.Where(a => a.IsPureAgent).Sum(a => a.Total);
        decimal taxable = supplies.Sum(a => a.Taxable);
        decimal cgst = supplies.Sum(a => a.Cgst), sgst = supplies.Sum(a => a.Sgst), igst = supplies.Sum(a => a.Igst);
        decimal before = taxable + cgst + sgst + igst + reimbursements;
        decimal grand = roundToRupee ? Math.Round(before, 0, MidpointRounding.AwayFromZero) : before;

        var summary = supplies
            .GroupBy(a => (a.HsnSacCode, a.TaxRatePercent))
            .OrderBy(g => g.Key.HsnSacCode ?? "~").ThenBy(g => g.Key.TaxRatePercent)
            .Select(g => new TaxSummaryRow(g.Key.HsnSacCode, g.Key.TaxRatePercent,
                g.Sum(a => a.Taxable), g.Sum(a => a.Cgst), g.Sum(a => a.Sgst), g.Sum(a => a.Igst)))
            .ToList();

        return new InvoiceTotals(amounts,
            amounts.Sum(a => a.Gross), amounts.Sum(a => a.Discount),
            taxable, cgst, sgst, igst, reimbursements, before, grand - before, grand, summary);
    }

    /// <summary>
    /// CGST+SGST when the supply stays inside the supplier's state, IGST otherwise. A place of supply
    /// of "96" (other countries) or "97" (other territory) is always IGST. Unknown places fall back to
    /// the supplier's own state, which is right for a walk-in customer at the counter.
    /// </summary>
    public static bool IsInterState(string? supplierState, string? placeOfSupply) =>
        !string.IsNullOrEmpty(supplierState) && !string.IsNullOrEmpty(placeOfSupply) && supplierState != placeOfSupply;
}

/// <summary>Amounts in words, Indian style: lakh and crore, "Rupees … and … Paise Only".</summary>
public static class AmountInWords
{
    private static readonly string[] Ones =
    [
        "", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten",
        "Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen", "Sixteen", "Seventeen", "Eighteen", "Nineteen",
    ];

    private static readonly string[] Tens = ["", "", "Twenty", "Thirty", "Forty", "Fifty", "Sixty", "Seventy", "Eighty", "Ninety"];

    public static string Rupees(decimal amount)
    {
        if (amount < 0) return "Minus " + Rupees(-amount);
        amount = InvoiceMath.Round2(amount);
        long rupees = (long)Math.Floor(amount);
        int paise = (int)((amount - rupees) * 100m);

        string words = rupees == 0 ? "Zero" : Whole(rupees);
        string result = "Rupees " + words;
        if (paise > 0) result += " and " + Below100(paise) + " Paise";
        return result + " Only";
    }

    private static string Whole(long n)
    {
        var parts = new List<string>();
        long crore = n / 10_000_000; n %= 10_000_000;
        long lakh = n / 100_000; n %= 100_000;
        long thousand = n / 1000; n %= 1000;
        long hundred = n / 100; n %= 100;

        if (crore > 0) parts.Add(Whole(crore) + " Crore");
        if (lakh > 0) parts.Add(Below100((int)lakh) + " Lakh");
        if (thousand > 0) parts.Add(Below100((int)thousand) + " Thousand");
        if (hundred > 0) parts.Add(Ones[hundred] + " Hundred");
        if (n > 0) parts.Add(Below100((int)n));
        return string.Join(" ", parts);
    }

    private static string Below100(int n) =>
        n < 20 ? Ones[n] : Tens[n / 10] + (n % 10 > 0 ? " " + Ones[n % 10] : "");
}
