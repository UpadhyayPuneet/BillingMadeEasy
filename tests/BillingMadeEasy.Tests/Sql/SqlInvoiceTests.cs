using System.Net;
using Microsoft.AspNetCore.Mvc.Testing;
using static BillingMadeEasy.Tests.Sql.WebFlow;

namespace BillingMadeEasy.Tests.Sql;

public sealed class SqlInvoiceTests(SqlDatabaseFixture db) : IClassFixture<SqlDatabaseFixture>
{
    private const string Edit = "/Sales/Invoices/Edit";

    private HttpClient Client() =>
        new SqlAppFactory(db).CreateClient(new WebApplicationFactoryClientOptions { AllowAutoRedirect = false });

    private Task<SalesSetup.Setup> SetupAsync(string customerState = "27", bool composition = false) =>
        SalesSetup.CreateAsync(db, customerState, composition);

    private static Dictionary<string, string> Invoice(SalesSetup.Setup s, string then = "draft", string rate = "4500", long? taxRateId = null, string qty = "2") =>
        SalesSetup.Invoice(s, then, rate, taxRateId, qty);

    private static string Unique(string prefix) => SalesSetup.Unique(prefix);

    [SqlFact]
    public async Task A_draft_has_no_number_and_issuing_gives_the_next_one()
    {
        var s = await SetupAsync();
        string draft = (await Post(s.Client, Edit, Edit, Invoice(s))).Location();
        Assert.Matches(@"^/Sales/Invoices/Edit/\d+$", draft);
        long id = long.Parse(draft.Split('/')[^1]);
        Assert.Equal(1, await db.ScalarAsync<int>("SELECT CASE WHEN InvoiceNumber IS NULL AND Status = 1 THEN 1 ELSE 0 END FROM tbl_SalesInvoices WHERE SalesInvoiceId = @id", new { id }));

        // Same state: CGST + SGST, computed by the server (9000 + 9% + 9% = 10620).
        Assert.Equal(10620m, await db.ScalarAsync<decimal>("SELECT GrandTotal FROM tbl_SalesInvoices WHERE SalesInvoiceId = @id", new { id }));
        Assert.Equal(810m, await db.ScalarAsync<decimal>("SELECT CgstTotal FROM tbl_SalesInvoices WHERE SalesInvoiceId = @id", new { id }));

        var issued = await Post(s.Client, draft, draft, Invoice(s, then: "issue"));
        Assert.Equal($"/Sales/Invoices/View/{id}", issued.Location());
        string page = await s.Client.GetStringAsync(issued.Location());
        Assert.Contains("INV-26-27-0001", page);
        Assert.Contains("Rupees Ten Thousand Six Hundred Twenty Only", page);
        Assert.Contains("TAX INVOICE", page);

        // Issued means frozen: the editor sends you to the document.
        Assert.Equal($"/Sales/Invoices/View/{id}", (await s.Client.GetAsync(draft)).Location());
        var edit = await Post(s.Client, issued.Location(), draft, Invoice(s, rate: "1"));
        Assert.Contains("has been issued, so it can&#x27;t be edited", await edit.Content.ReadAsStringAsync());
        Assert.Equal(10620m, await db.ScalarAsync<decimal>("SELECT GrandTotal FROM tbl_SalesInvoices WHERE SalesInvoiceId = @id", new { id }));
        Assert.Equal(1, await db.ScalarAsync<int>("SELECT COUNT(*) FROM tbl_IssuedNumbers WHERE TenantId = @TenantId", new { s.TenantId }));
    }

    [SqlFact]
    public async Task Another_state_is_IGST()
    {
        var s = await SetupAsync(customerState: "29");
        string draft = (await Post(s.Client, Edit, Edit, Invoice(s))).Location();
        long id = long.Parse(draft.Split('/')[^1]);
        Assert.Equal((1620m, 0m, "29"), (
            await db.ScalarAsync<decimal>("SELECT IgstTotal FROM tbl_SalesInvoices WHERE SalesInvoiceId = @id", new { id }),
            await db.ScalarAsync<decimal>("SELECT CgstTotal FROM tbl_SalesInvoices WHERE SalesInvoiceId = @id", new { id }),
            await db.ScalarAsync<string>("SELECT PlaceOfSupply FROM tbl_SalesInvoices WHERE SalesInvoiceId = @id", new { id })));
    }

    [SqlFact]
    public async Task A_GST_rate_that_has_ended_is_refused_with_the_reason()
    {
        var s = await SetupAsync();
        var response = await Post(s.Client, Edit, Edit, Invoice(s, taxRateId: s.Gst12));
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Contains("That GST rate doesn&#x27;t apply on", await response.Content.ReadAsStringAsync());
    }

    [SqlFact]
    public async Task The_customer_gets_their_agreed_price_and_their_last_price()
    {
        var s = await SetupAsync();
        string item = $"/Catalog/Item/{s.ItemId}";
        await Post(s.Client, item, item + "?handler=CustomerPrice", new() { ["partyId"] = s.CustomerId.ToString(), ["price"] = "4200", ["minQuantity"] = "1" });

        string json = await s.Client.GetStringAsync($"{Edit}?handler=Item&offeringId={s.ItemId}&partyId={s.CustomerId}&qty=1");
        Assert.Contains("\"price\":4200", json);
        Assert.Contains("\"standard\":4500", json);

        string draft = (await Post(s.Client, Edit, Edit, Invoice(s, then: "issue", rate: "4200"))).Location();
        json = await s.Client.GetStringAsync($"{Edit}?handler=Item&offeringId={s.ItemId}&partyId={s.CustomerId}&qty=1");
        Assert.Contains("\"lastPrice\":4200", json);
        Assert.Contains("\"lastInvoice\":\"INV-26-27-0001\"", json);
    }

    [SqlFact]
    public async Task Cancelling_needs_a_reason_and_keeps_the_number()
    {
        var s = await SetupAsync();
        string view = (await Post(s.Client, Edit, Edit, Invoice(s, then: "issue"))).Location();
        Assert.Contains("Say why it is being cancelled", await (await Post(s.Client, view, view + "?handler=Cancel", new() { ["reason"] = "" })).Content.ReadAsStringAsync());

        Assert.Equal(view, (await Post(s.Client, view, view + "?handler=Cancel", new() { ["reason"] = "Wrong customer selected" })).Location());
        Assert.Equal(1, await db.ScalarAsync<int>("SELECT COUNT(*) FROM tbl_IssuedNumbers WHERE TenantId = @TenantId AND IsCancelled = 1 AND FullNumber = 'INV-26-27-0001'", new { s.TenantId }));

        // The next invoice takes the next number; the cancelled one is never reused.
        string next = (await Post(s.Client, Edit, Edit, Invoice(s, then: "issue"))).Location();
        Assert.Contains("INV-26-27-0002", await s.Client.GetStringAsync(next));
    }

    [SqlFact]
    public async Task A_composition_dealer_issues_a_bill_of_supply_without_tax()
    {
        var s = await SetupAsync(composition: true);
        string view = (await Post(s.Client, Edit, Edit, Invoice(s, then: "issue"))).Location();
        string page = await s.Client.GetStringAsync(view);
        Assert.Contains("BILL OF SUPPLY", page);
        Assert.Contains("BOS-26-27-0001", page);
        Assert.Contains("not eligible to collect tax", page);
        long id = long.Parse(view.Split('/')[^1]);
        Assert.Equal((9000m, 0m), (
            await db.ScalarAsync<decimal>("SELECT GrandTotal FROM tbl_SalesInvoices WHERE SalesInvoiceId = @id", new { id }),
            await db.ScalarAsync<decimal>("SELECT CgstTotal + SgstTotal + IgstTotal FROM tbl_SalesInvoices WHERE SalesInvoiceId = @id", new { id })));
    }

    [SqlFact]
    public async Task The_plan_limit_is_checked_when_issuing()
    {
        var s = await SetupAsync();
        await Post(s.Client, Edit, Edit, Invoice(s, then: "issue"));
        string draft = (await Post(s.Client, Edit, Edit, Invoice(s))).Location();
        long id = long.Parse(draft.Split('/')[^1]);
        var result = await db.RowAsync(
            "EXEC dbo.usp_SalesInvoice_Issue @TenantId = @TenantId, @SalesInvoiceId = @id, @SellerSnapshot = N'{}', @Today = @today, @MonthlyLimit = 1, @ActionByUserId = NULL",
            new { s.TenantId, id, today = DateTime.UtcNow.AddHours(5.5).Date });
        Assert.Equal(5, (int)result.ResultCode);
        string message = result.ResultMessage;
        Assert.StartsWith("Your plan includes 1 invoices a month", message);
    }

    [SqlFact]
    public async Task A_walk_in_customer_with_a_mistyped_GSTIN_is_caught()
    {
        var s = await SetupAsync();
        var form = Invoice(s);
        form.Remove("Form.PartyId");
        form["Form.BuyerName"] = "Ramesh Traders";
        form["Form.BuyerGstin"] = "27AAPCR1234K1Z0";
        Assert.Contains("That isn&#x27;t a valid GSTIN", await (await Post(s.Client, Edit, Edit, form)).Content.ReadAsStringAsync());

        form["Form.BuyerGstin"] = "";
        Assert.Matches(@"^/Sales/Invoices/Edit/\d+$", (await Post(s.Client, Edit, Edit, form)).Location());
    }
}
