namespace BillingMadeEasy.Core.Billing;

/// <summary>tbl_NumberSeries.DocumentType and tbl_IssuedNumbers.DocumentType.</summary>
public static class DocumentTypes
{
    public const byte TaxInvoice = 1;
    public const byte BillOfSupply = 2;
    public const byte CreditNote = 3;
    public const byte DebitNote = 4;
    public const byte Quotation = 5;
    public const byte DeliveryChallan = 6;
    public const byte Receipt = 7;

    public static IReadOnlyList<(byte Code, string Name, string Hint)> All { get; } =
    [
        (TaxInvoice, "Tax invoice", "Sales that carry GST"),
        (BillOfSupply, "Bill of supply", "Exempt sales, or every sale under the composition scheme"),
        (CreditNote, "Credit note", "Returns, discounts after billing, corrections that reduce an invoice"),
        (DebitNote, "Debit note", "Corrections that increase an invoice"),
        (Quotation, "Quotation", "Estimates and proforma invoices"),
        (DeliveryChallan, "Delivery challan", "Goods sent without a sale: job work, approval, branch transfer"),
        (Receipt, "Receipt", "Money received"),
    ];

    public static string Name(byte code) => All.FirstOrDefault(d => d.Code == code).Name ?? "Document";
}

/// <summary>
/// Formats a document number from its parts. Mirrors dbo.fn_FormatDocNumber exactly (a test holds
/// them together), so a preview shown on screen is the number that will be issued.
/// </summary>
public static class DocumentNumber
{
    /// <summary>Rule 46(b): a tax invoice number is at most 16 characters.</summary>
    public const int MaxLength = 16;

    public static string Format(string? prefix, string? suffix, string separator, byte yearFormat, int financialYear, long sequence, int padWidth)
    {
        string? year = yearFormat switch
        {
            1 => $"{financialYear}-{(financialYear + 1) % 100:00}",
            2 => $"{financialYear % 100:00}-{(financialYear + 1) % 100:00}",
            3 => financialYear.ToString(System.Globalization.CultureInfo.InvariantCulture),
            _ => null,
        };
        // A run that outgrows its padding widens (9999 → 10000); it never wraps back to 0000.
        string padded = sequence.ToString(System.Globalization.CultureInfo.InvariantCulture).PadLeft(padWidth, '0');

        string result = string.IsNullOrEmpty(prefix) ? "" : prefix;
        if (year is not null) result = result.Length > 0 ? result + separator + year : year;
        result = result.Length > 0 ? result + separator + padded : padded;
        if (!string.IsNullOrEmpty(suffix)) result += separator + suffix;
        return result;
    }

    /// <summary>April to March, from the document date.</summary>
    public static int FinancialYear(DateOnly date) => date.Month >= 4 ? date.Year : date.Year - 1;
}
