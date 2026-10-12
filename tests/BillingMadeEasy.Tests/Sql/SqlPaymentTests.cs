using static BillingMadeEasy.Tests.Sql.WebFlow;

namespace BillingMadeEasy.Tests.Sql;

public sealed class SqlPaymentTests(SqlDatabaseFixture db) : IClassFixture<SqlDatabaseFixture>
{
    private const string Record = "/Sales/Payments/Record";
    private static string Today => DateTime.UtcNow.AddHours(5.5).ToString("yyyy-MM-dd");

    private static Dictionary<string, string> Payment(SalesSetup.Setup s, string amount, string mode = "3", string? reference = null,
        params (long Invoice, string Amount, string Tds)[] allocations)
    {
        var form = new Dictionary<string, string>
        {
            ["Form.PartyId"] = s.CustomerId.ToString(),
            ["Form.PaymentDate"] = Today,
            ["Form.Amount"] = amount,
            ["Form.Mode"] = mode,
            ["Form.Reference"] = reference ?? "UTR" + Guid.NewGuid().ToString("N")[..12].ToUpperInvariant(),
        };
        for (int i = 0; i < allocations.Length; i++)
        {
            form[$"Form.Allocations[{i}].SalesInvoiceId"] = allocations[i].Invoice.ToString();
            form[$"Form.Allocations[{i}].Amount"] = allocations[i].Amount;
            form[$"Form.Allocations[{i}].TdsAmount"] = allocations[i].Tds;
        }
        return form;
    }

    private Task<decimal> Balance(long invoiceId) =>
        db.ScalarAsync<decimal>("SELECT GrandTotal - AmountPaid FROM tbl_SalesInvoices WHERE SalesInvoiceId = @invoiceId", new { invoiceId });

    [SqlFact]
    public async Task Money_and_TDS_together_settle_an_invoice()
    {
        var s = await SalesSetup.CreateAsync(db);
        long invoice = await SalesSetup.IssueAsync(s);   // 2 × 4500 + 18% = 10,620

        var saved = await Post(s.Client, Record, Record, Payment(s, "9720", allocations: (invoice, "9720", "900")));
        Assert.Matches(@"^/Sales/Payments/View/\d+$", saved.Location());
        string receipt = await s.Client.GetStringAsync(saved.Location());
        Assert.Contains("RCT-26-27-0001", receipt);
        Assert.Contains("Rupees Nine Thousand Seven Hundred Twenty Only", receipt);

        Assert.Equal(0m, await Balance(invoice));
        Assert.Equal(900m, await db.ScalarAsync<decimal>("SELECT TdsDeducted FROM tbl_SalesInvoices WHERE SalesInvoiceId = @invoice", new { invoice }));
        string page = await s.Client.GetStringAsync($"/Sales/Invoices/View/{invoice}");
        Assert.Contains("TDS deducted", page);
        Assert.Contains("RCT-26-27-0001", page);   // in the invoice's payment history
    }

    [SqlFact]
    public async Task More_than_owed_is_refused_and_the_rest_is_an_advance()
    {
        var s = await SalesSetup.CreateAsync(db);
        long invoice = await SalesSetup.IssueAsync(s);

        var tooMuch = await Post(s.Client, Record, Record, Payment(s, "20000", allocations: (invoice, "20000", "")));
        Assert.Contains("has only", await tooMuch.Content.ReadAsStringAsync());

        var notReceived = await Post(s.Client, Record, Record, Payment(s, "5000", allocations: (invoice, "10620", "")));
        Assert.Contains("more than the", await notReceived.Content.ReadAsStringAsync());

        var withAdvance = await Post(s.Client, Record, Record, Payment(s, "15000", allocations: (invoice, "10620", "")));
        Assert.Contains("₹4,380 is kept as an advance", await s.Client.GetStringAsync(withAdvance.Location()));
        Assert.Equal(0m, await Balance(invoice));

        // A later invoice is settled from the advance.
        long next = await SalesSetup.IssueAsync(s, rate: "1000", qty: "1");   // 1,180
        long paymentId = long.Parse(withAdvance.Location().Split('/')[^1]);
        string view = withAdvance.Location();
        var applied = await Post(s.Client, view, view + "?handler=Apply", new()
        {
            ["Apply[0].SalesInvoiceId"] = next.ToString(), ["Apply[0].Amount"] = "1180",
        });
        Assert.Equal(view, applied.Location());
        Assert.Equal(0m, await Balance(next));
        Assert.Equal(3200m, await db.ScalarAsync<decimal>(
            "SELECT p.Amount - SUM(a.Amount) FROM tbl_Payments p JOIN tbl_PaymentAllocations a ON a.PaymentId = p.PaymentId AND a.IsActive = 1 WHERE p.PaymentId = @paymentId GROUP BY p.Amount",
            new { paymentId }));
    }

    [SqlFact]
    public async Task The_same_UTR_is_never_counted_twice()
    {
        var s = await SalesSetup.CreateAsync(db);
        Assert.Matches(@"^/Sales/Payments/View/\d+$", (await Post(s.Client, Record, Record, Payment(s, "1000", reference: "SBIN123456789"))).Location());
        var again = await Post(s.Client, Record, Record, Payment(s, "1000", reference: "SBIN123456789"));
        Assert.Contains("Reference SBIN123456789 is already recorded on RCT-26-27-0001", await again.Content.ReadAsStringAsync());
    }

    [SqlFact]
    public async Task Cash_of_two_lakh_or_more_in_a_day_is_refused()
    {
        var s = await SalesSetup.CreateAsync(db);
        Assert.Matches(@"^/Sales/Payments/View/\d+$", (await Post(s.Client, Record, Record, Payment(s, "150000", mode: "1", reference: ""))).Location());
        var second = await Post(s.Client, Record, Record, Payment(s, "60000", mode: "1", reference: ""));
        Assert.Contains("s.269ST", await second.Content.ReadAsStringAsync());
    }

    [SqlFact]
    public async Task Reversing_needs_a_reason_reopens_the_invoice_and_keeps_the_number()
    {
        var s = await SalesSetup.CreateAsync(db);
        long invoice = await SalesSetup.IssueAsync(s);
        string view = (await Post(s.Client, Record, Record, Payment(s, "10620", mode: "4", reference: "000123", allocations: (invoice, "10620", "")))).Location();
        Assert.Equal(0m, await Balance(invoice));

        // Payments against an invoice block cancelling it.
        string invoiceView = $"/Sales/Invoices/View/{invoice}";
        Assert.Contains("Payments are recorded against this invoice",
            await (await Post(s.Client, invoiceView, invoiceView + "?handler=Cancel", new() { ["reason"] = "Wrong customer" })).Content.ReadAsStringAsync());

        Assert.Contains("Say why it is being reversed", await (await Post(s.Client, view, view + "?handler=Reverse", new() { ["reason"] = "" })).Content.ReadAsStringAsync());
        Assert.Equal(view, (await Post(s.Client, view, view + "?handler=Reverse", new() { ["reason"] = "Cheque bounced" })).Location());

        Assert.Equal(10620m, await Balance(invoice));
        Assert.Equal(1, await db.ScalarAsync<int>("SELECT COUNT(*) FROM tbl_IssuedNumbers WHERE TenantId = @TenantId AND DocumentType = 7 AND IsCancelled = 1", new { s.TenantId }));
        Assert.Contains("Cheque bounced", await s.Client.GetStringAsync(view));
    }

    [SqlFact]
    public async Task Bank_and_UPI_payments_need_their_UTR()
    {
        var s = await SalesSetup.CreateAsync(db);
        var missing = await Post(s.Client, Record, Record, Payment(s, "1000", mode: "2", reference: ""));
        Assert.Contains("Enter the UTR", await missing.Content.ReadAsStringAsync());
    }
}
