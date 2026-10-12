namespace BillingMadeEasy.Core.Billing;

/// <summary>tbl_Payments.Mode.</summary>
public static class PaymentModes
{
    public const byte Cash = 1;
    public const byte Upi = 2;
    public const byte BankTransfer = 3;
    public const byte Cheque = 4;
    public const byte Card = 5;
    public const byte Other = 6;

    public static IReadOnlyList<(byte Code, string Name, string ReferenceLabel)> All { get; } =
    [
        (BankTransfer, "Bank transfer (NEFT/RTGS/IMPS)", "UTR number"),
        (Upi, "UPI", "UPI reference (UTR)"),
        (Cheque, "Cheque / DD", "Cheque number"),
        (Cash, "Cash", "Receipt book no."),
        (Card, "Card", "Approval code"),
        (Other, "Other", "Reference"),
    ];

    public static string Name(byte mode) => All.FirstOrDefault(m => m.Code == mode).Name ?? "Other";

    /// <summary>Income Tax Act s.269ST: cash of this much or more from one person in a day is not allowed.</summary>
    public const decimal CashLimitPerDay = 200_000m;
}

/// <summary>An open invoice as allocation sees it.</summary>
public sealed record OpenBalance(long InvoiceId, decimal Balance, decimal Tds = 0);

public sealed record Allocation(long InvoiceId, decimal Amount, decimal Tds);

public static class PaymentAllocator
{
    /// <summary>
    /// Spreads money over invoices oldest first, the way customers and auditors expect: each invoice
    /// takes its TDS (if any is entered for it) and then money up to its balance. What is left is an
    /// advance. Pure: same input, same split.
    /// </summary>
    public static (IReadOnlyList<Allocation> Allocations, decimal Advance) Oldest(decimal amount, IEnumerable<OpenBalance> oldestFirst)
    {
        ArgumentOutOfRangeException.ThrowIfNegative(amount);
        var result = new List<Allocation>();
        decimal left = amount;
        foreach (var inv in oldestFirst)
        {
            decimal tds = Math.Clamp(inv.Tds, 0, inv.Balance);
            decimal take = Math.Min(inv.Balance - tds, left);
            if (take > 0 || tds > 0) result.Add(new(inv.InvoiceId, take, tds));
            left -= take;
        }
        return (result, left);
    }
}
