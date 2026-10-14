using static BillingMadeEasy.Tests.Sql.WebFlow;

namespace BillingMadeEasy.Tests.Sql;

public sealed class SqlCreditNoteTests(SqlDatabaseFixture db) : IClassFixture<SqlDatabaseFixture>
{
    private static string Today => DateTime.UtcNow.AddHours(5.5).ToString("yyyy-MM-dd");

    private async Task<long> LineIdAsync(long invoiceId) =>
        await db.ScalarAsync<long>("SELECT TOP (1) SalesInvoiceLineId FROM tbl_SalesInvoiceLines WHERE SalesInvoiceId = @invoiceId ORDER BY LineNumber", new { invoiceId });

    private Task<decimal> Balance(long invoiceId) =>
        db.ScalarAsync<decimal>("SELECT GrandTotal - AmountPaid FROM tbl_SalesInvoices WHERE SalesInvoiceId = @invoiceId", new { invoiceId });

    private static Dictionary<string, string> Note(long lineId, string qty, string taxable = "", string reason = "1", string? date = null) => new()
    {
        ["Form.NoteDate"] = date ?? Today,
        ["Form.ReasonCode"] = reason,
        ["Form.Lines[0].SalesInvoiceLineId"] = lineId.ToString(),
        ["Form.Lines[0].Quantity"] = qty,
        ["Form.Lines[0].Taxable"] = taxable,
    };

    private static string New(long invoiceId) => $"/Sales/CreditNotes/New?invoiceId={invoiceId}";

    [SqlFact]
    public async Task A_return_reduces_the_invoice_and_the_rest_is_customer_credit()
    {
        var s = await SalesSetup.CreateAsync(db);
        long invoice = await SalesSetup.IssueAsync(s);                    // 2 × 4500 + 18% = 10,620
        long line = await LineIdAsync(invoice);

        var issued = await Post(s.Client, New(invoice), New(invoice), Note(line, "1"));
        Assert.Matches(@"^/Sales/CreditNotes/View/\d+$", issued.Location());
        string page = await s.Client.GetStringAsync(issued.Location());
        Assert.Contains("CREDIT NOTE", page);
        Assert.Contains("Rupees Five Thousand Three Hundred Ten Only", page);   // 4500 + 405 + 405
        Assert.Equal(5310m, await Balance(invoice));

        // The invoice was half paid by the note; a payment for the rest settles it.
        Assert.Equal(5310m, await db.ScalarAsync<decimal>("SELECT CreditedAmount FROM tbl_SalesInvoices WHERE SalesInvoiceId = @invoice", new { invoice }));
        Assert.Contains("CN-", await s.Client.GetStringAsync($"/Sales/Invoices/View/{invoice}"));
    }

    [SqlFact]
    public async Task Never_more_than_was_billed_and_the_whole_invoice_comes_back_exactly()
    {
        var s = await SalesSetup.CreateAsync(db);
        long invoice = await SalesSetup.IssueAsync(s);
        long line = await LineIdAsync(invoice);

        var tooMany = await Post(s.Client, New(invoice), New(invoice), Note(line, "3"));
        Assert.Contains("Only 2 can still be credited", await tooMany.Content.ReadAsStringAsync());

        Assert.Matches(@"^/Sales/CreditNotes/View/\d+$", (await Post(s.Client, New(invoice), New(invoice), Note(line, "1"))).Location());
        Assert.Matches(@"^/Sales/CreditNotes/View/\d+$", (await Post(s.Client, New(invoice), New(invoice), Note(line, "1"))).Location());
        Assert.Equal(10620m, await db.ScalarAsync<decimal>("SELECT SUM(GrandTotal) FROM tbl_CreditNotes WHERE SalesInvoiceId = @invoice AND Status = 2", new { invoice }));
        Assert.Equal(0m, await Balance(invoice));

        // Nothing left: the page says so instead of offering a form.
        Assert.Contains("has been credited", await s.Client.GetStringAsync(New(invoice)));
        // A credited invoice can't be cancelled underneath its notes.
        string view = $"/Sales/Invoices/View/{invoice}";
        Assert.Contains("Credit notes are issued against this invoice",
            await (await Post(s.Client, view, view + "?handler=Cancel", new() { ["reason"] = "Wrong customer" })).Content.ReadAsStringAsync());
    }

    [SqlFact]
    public async Task A_paid_invoice_gives_credit_to_apply_or_refund_and_cancelling_restores_everything()
    {
        var s = await SalesSetup.CreateAsync(db);
        long paid = await SalesSetup.IssueAsync(s);
        string record = "/Sales/Payments/Record";
        await Post(s.Client, record, record, new()
        {
            ["Form.PartyId"] = s.CustomerId.ToString(), ["Form.PaymentDate"] = Today, ["Form.Amount"] = "10620", ["Form.Mode"] = "3",
            ["Form.Reference"] = SalesSetup.Unique("UTR"), ["Form.Allocations[0].SalesInvoiceId"] = paid.ToString(), ["Form.Allocations[0].Amount"] = "10620",
        });
        long open = await SalesSetup.IssueAsync(s, rate: "1000", qty: "1");   // 1,180 owed

        // A discount of ₹1,000 + GST on the paid invoice: nothing is owed on it, so it is all credit.
        string view = (await Post(s.Client, New(paid), New(paid), Note(await LineIdAsync(paid), "", "1000", reason: "2"))).Location();
        Assert.Matches(@"^/Sales/CreditNotes/View/\d+$", view);
        long noteId = long.Parse(view.Split('/')[^1]);
        Assert.Contains("Apply the credit", await s.Client.GetStringAsync(view));

        Assert.Equal(view, (await Post(s.Client, view, view + "?handler=Apply", new()
        {
            ["Apply[0].SalesInvoiceId"] = open.ToString(), ["Apply[0].Amount"] = "1000",
        })).Location());
        Assert.Equal(180m, await Balance(open));

        // The ₹180 left is refunded; a bank refund needs its UTR.
        var noUtr = await Post(s.Client, view, view + "?handler=Refund", new() { ["Refund.RefundDate"] = Today, ["Refund.Amount"] = "180", ["Refund.Mode"] = "3" });
        Assert.Contains("Enter the UTR", await noUtr.Content.ReadAsStringAsync());
        var tooMuch = await Post(s.Client, view, view + "?handler=Refund", new() { ["Refund.RefundDate"] = Today, ["Refund.Amount"] = "500", ["Refund.Mode"] = "1" });
        Assert.Contains("is left to refund", await tooMuch.Content.ReadAsStringAsync());
        Assert.Equal(view, (await Post(s.Client, view, view + "?handler=Refund", new() { ["Refund.RefundDate"] = Today, ["Refund.Amount"] = "180", ["Refund.Mode"] = "1" })).Location());

        // Refunded money blocks cancelling until the refund is undone; cancelling then reopens the invoice it settled.
        Assert.Contains("Undo the refund first", await (await Post(s.Client, view, view + "?handler=Cancel", new() { ["reason"] = "Wrong invoice" })).Content.ReadAsStringAsync());
        long refundId = await db.ScalarAsync<long>("SELECT CreditNoteRefundId FROM tbl_CreditNoteRefunds WHERE CreditNoteId = @noteId", new { noteId });
        Assert.Equal(view, (await Post(s.Client, view, view + "?handler=UndoRefund", new() { ["refundId"] = refundId.ToString(), ["reason"] = "Entered twice" })).Location());
        Assert.Equal(view, (await Post(s.Client, view, view + "?handler=Cancel", new() { ["reason"] = "Wrong invoice" })).Location());
        Assert.Equal(1180m, await Balance(open));
        Assert.Equal(1, await db.ScalarAsync<int>("SELECT COUNT(*) FROM tbl_IssuedNumbers WHERE TenantId = @TenantId AND DocumentType = 3 AND IsCancelled = 1", new { s.TenantId }));
    }

    [SqlFact]
    public async Task Dates_and_reasons_are_checked()
    {
        var s = await SalesSetup.CreateAsync(db);
        long invoice = await SalesSetup.IssueAsync(s);
        long line = await LineIdAsync(invoice);

        var beforeInvoice = await Post(s.Client, New(invoice), New(invoice), Note(line, "1", date: DateTime.UtcNow.AddHours(5.5).AddDays(-400).ToString("yyyy-MM-dd")));
        Assert.Contains("can&#x27;t be dated before its invoice", await beforeInvoice.Content.ReadAsStringAsync());

        var future = await Post(s.Client, New(invoice), New(invoice), Note(line, "1", date: DateTime.UtcNow.AddHours(5.5).AddDays(3).ToString("yyyy-MM-dd")));
        Assert.Contains("can&#x27;t be dated in the future", await future.Content.ReadAsStringAsync());

        var other = await Post(s.Client, New(invoice), New(invoice), Note(line, "1", reason: "7"));
        Assert.Contains("Describe the reason", await other.Content.ReadAsStringAsync());

        var returnWithoutQty = await Post(s.Client, New(invoice), New(invoice), Note(line, "", "100", reason: "1"));
        Assert.Contains("enter the quantity that came back", await returnWithoutQty.Content.ReadAsStringAsync());
    }
}
