namespace BillingMadeEasy.Core.Billing;

/// <summary>
/// Why a credit note is issued. The codes are the ones GSTR-1 used for credit notes, so a report can
/// carry them unchanged. "Change in place of supply" and "finalisation of provisional assessment" are
/// left out on purpose: the first is corrected by cancelling and re-invoicing, the second is rare
/// enough to go under "Others".
/// </summary>
public static class CreditNoteReasons
{
    public const byte SalesReturn = 1;
    public const byte PostSaleDiscount = 2;
    public const byte DeficiencyInService = 3;
    public const byte Correction = 4;
    public const byte Others = 7;

    public static IReadOnlyList<(byte Code, string Name, string Hint)> All { get; } =
    [
        (SalesReturn, "Goods returned", "The customer sent some or all of the goods back"),
        (PostSaleDiscount, "Discount after sale", "A discount agreed before the sale and passed on now, e.g. a volume or prompt-payment discount"),
        (DeficiencyInService, "Deficiency in service", "The service fell short and you are crediting part of it"),
        (Correction, "Charged too much", "The invoice had a wrong rate, quantity or value that was too high"),
        (Others, "Other", "Anything else that reduces what the customer owes"),
    ];

    public static bool IsValid(byte code) => All.Any(r => r.Code == code);

    public static string Name(byte code) => All.FirstOrDefault(r => r.Code == code).Name ?? "Other";

    /// <summary>A return reduces quantities; the others reduce value and leave the quantity alone.</summary>
    public static bool ReducesQuantity(byte code) => code == SalesReturn;
}

/// <summary>GST s.34 limits for a credit note against an invoice.</summary>
public static class CreditNoteRules
{
    /// <summary>
    /// The tax on a credit note can be reduced only if it is declared by 30 November after the end of
    /// the financial year of the original supply (s.34(2), as amended from 1 Oct 2022). The annual
    /// return can make it earlier; we can't know when that is filed, so the statutory date is used.
    /// </summary>
    public static DateOnly LastDate(DateOnly invoiceDate) => new(DocumentNumber.FinancialYear(invoiceDate) + 1, 11, 30);
}

/// <summary>An original invoice line and how much of it earlier credit notes already took back.</summary>
public sealed record CreditableLine(
    long SalesInvoiceLineId,
    decimal Quantity,
    decimal Taxable,
    decimal TaxRatePercent,
    decimal Cgst,
    decimal Sgst,
    decimal Igst,
    bool IsPureAgent,
    decimal CreditedQuantity = 0,
    decimal CreditedTaxable = 0,
    decimal CreditedCgst = 0,
    decimal CreditedSgst = 0,
    decimal CreditedIgst = 0)
{
    public decimal QuantityLeft => Quantity - CreditedQuantity;
    public decimal TaxableLeft => Taxable - CreditedTaxable;
    public decimal UnitTaxable => Quantity == 0 ? 0 : Taxable / Quantity;
}

/// <summary>What is being credited on one line: a quantity returned, a value, or both.</summary>
public sealed record CreditRequest(long SalesInvoiceLineId, decimal Quantity, decimal? Taxable);

public sealed record CreditLineAmounts(long SalesInvoiceLineId, decimal Quantity, decimal Taxable, decimal TaxRatePercent,
    decimal Cgst, decimal Sgst, decimal Igst, bool IsPureAgent)
{
    public decimal Tax => Cgst + Sgst + Igst;
    public decimal Total => Taxable + Tax;
}

public sealed record CreditNoteTotals(IReadOnlyList<CreditLineAmounts> Lines, decimal Taxable, decimal Cgst, decimal Sgst, decimal Igst,
    decimal Reimbursements, decimal RoundOff, decimal GrandTotal)
{
    public decimal Tax => Cgst + Sgst + Igst;
}

/// <summary>
/// Credit note arithmetic. Tax is taken back at the original line's rate and on the original's
/// basis (CGST+SGST or IGST), because a credit note reverses a supply that was already taxed one way.
/// Whatever takes a line to zero takes back exactly what is left of it, so returning everything
/// cancels the invoice to the paisa however many notes it took.
/// </summary>
public static class CreditNoteMath
{
    public static (CreditLineAmounts? Line, string? Problem) Line(CreditableLine original, CreditRequest request, bool interState)
    {
        if (request.Quantity < 0 || request.Taxable < 0) return (null, "Amounts can't be negative");
        if (request.Quantity > original.QuantityLeft)
            return (null, original.QuantityLeft <= 0 ? "Everything on this line has already been credited" : $"Only {Trim(original.QuantityLeft)} can still be credited");

        decimal taxable;
        if (request.Taxable is decimal entered) taxable = InvoiceMath.Round2(entered);
        else if (request.Quantity == original.QuantityLeft) taxable = original.TaxableLeft;
        else taxable = Math.Min(InvoiceMath.Round2(original.UnitTaxable * request.Quantity), original.TaxableLeft);

        if (taxable > original.TaxableLeft)
            return (null, original.TaxableLeft <= 0 ? "The full value of this line has already been credited" : $"Only {original.TaxableLeft:0.00} of this line's value can still be credited");
        if (taxable == 0 && request.Quantity == 0) return (null, null);
        if (taxable == 0) return (null, "Enter the value being credited");

        decimal rate = original.IsPureAgent ? 0 : original.TaxRatePercent;
        decimal cgst = 0, sgst = 0, igst = 0;
        if (taxable == original.TaxableLeft)
        {
            // The last of the line: exactly the tax that is left, so nothing is stranded by rounding.
            cgst = original.Cgst - original.CreditedCgst;
            sgst = original.Sgst - original.CreditedSgst;
            igst = original.Igst - original.CreditedIgst;
        }
        else if (rate > 0)
        {
            if (interState) igst = InvoiceMath.Round2(taxable * rate / 100m);
            else { cgst = InvoiceMath.Round2(taxable * rate / 200m); sgst = cgst; }
        }
        return (new CreditLineAmounts(original.SalesInvoiceLineId, request.Quantity, taxable, rate, cgst, sgst, igst, original.IsPureAgent), null);
    }

    /// <param name="invoiceGrandTotal">The original invoice's total.</param>
    /// <param name="creditedBefore">Totals of earlier credit notes on the invoice that are not cancelled.</param>
    /// <param name="settlesEverything">True when, with this note, every line is fully credited.</param>
    public static CreditNoteTotals Totals(IReadOnlyList<CreditLineAmounts> lines, bool roundToRupee,
        decimal invoiceGrandTotal, decimal creditedBefore, bool settlesEverything)
    {
        var supplies = lines.Where(l => !l.IsPureAgent).ToList();
        decimal taxable = supplies.Sum(l => l.Taxable);
        decimal cgst = supplies.Sum(l => l.Cgst), sgst = supplies.Sum(l => l.Sgst), igst = supplies.Sum(l => l.Igst);
        decimal reimbursements = lines.Where(l => l.IsPureAgent).Sum(l => l.Total);
        decimal before = taxable + cgst + sgst + igst + reimbursements;

        decimal grand = settlesEverything
            ? invoiceGrandTotal - creditedBefore                  // the invoice's own round-off comes back with the last of it
            : roundToRupee ? Math.Round(before, 0, MidpointRounding.AwayFromZero) : before;
        // Separate notes each rounded up could otherwise add up to more than the invoice.
        grand = Math.Min(grand, invoiceGrandTotal - creditedBefore);

        return new CreditNoteTotals(lines, taxable, cgst, sgst, igst, reimbursements, grand - before, grand);
    }

    private static string Trim(decimal d) => (d / 1.0000000000000000000000000000m).ToString("0.####", System.Globalization.CultureInfo.InvariantCulture);
}
