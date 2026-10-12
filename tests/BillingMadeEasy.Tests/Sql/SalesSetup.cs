using Microsoft.AspNetCore.Mvc.Testing;
using static BillingMadeEasy.Tests.Sql.WebFlow;

namespace BillingMadeEasy.Tests.Sql;

/// <summary>A ready-to-invoice business, shared by the invoice and payment tests.</summary>
internal static class SalesSetup
{
    public static string Unique(string prefix) => prefix + Guid.NewGuid().ToString("N")[..10];

    public static string Gstin(string first14)
    {
        const string cs = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        int sum = 0;
        for (int i = 0; i < 14; i++) { int v = cs.IndexOf(first14[i]) * (i % 2 == 1 ? 2 : 1); sum += v / 36 + v % 36; }
        return first14 + cs[(36 - sum % 36) % 36];
    }

    public sealed record Setup(HttpClient Client, long TenantId, long ProfileId, long Gst18, long Gst12, long ItemId, long CustomerId);

    /// <summary>A Maharashtra business with a product, and a customer in Karnataka or Maharashtra.</summary>
    public static async Task<Setup> CreateAsync(SqlDatabaseFixture db, string customerState = "27", bool composition = false)
    {
        string email = Unique("i") + "@test.in";
        var (tenantId, _) = await db.ProvisionAsync(Unique("T"), "Wheels & Co", email);
        var client = new SqlAppFactory(db).CreateClient(new WebApplicationFactoryClientOptions { AllowAutoRedirect = false });
        await SignIn(client, email, SqlDatabaseFixture.Password);
        long profileId = await db.ScalarAsync<long>("SELECT BusinessProfileId FROM tbl_BusinessProfiles WHERE TenantId = @tenantId", new { tenantId });
        string profile = $"/Business/Profile/{profileId}";
        var saved = await Post(client, profile, profile, new()
        {
            ["Form.ProfileName"] = "Wheels & Co", ["Form.LegalName"] = "Wheels and Company LLP", ["Form.Gstin"] = Gstin("27AAGFW1234A1Z"),
            ["Form.RoundOffTotal"] = "true", ["Form.IsComposition"] = composition ? "true" : "false",
        });
        Assert.Equal(profile, saved.Location());

        long gst18 = await db.ScalarAsync<long>("SELECT TaxRateId FROM tbl_TaxRates WHERE TenantId = @tenantId AND TaxName = 'GST 18%'", new { tenantId });
        long gst12 = await db.ScalarAsync<long>("SELECT TaxRateId FROM tbl_TaxRates WHERE TenantId = @tenantId AND TaxName = 'GST 12%'", new { tenantId });
        string item = (await Post(client, "/Catalog/Item?type=product", "/Catalog/Item", new()
        {
            ["Form.OfferingType"] = "1", ["Form.OfferingName"] = "Tyre 145/80 R12", ["Form.TaxRateId"] = gst18.ToString(), ["Form.HsnSacCode"] = "40111010",
            ["Form.DefaultPrice"] = "4500", ["Form.IsPriceInclusive"] = "false", ["Form.IsSellable"] = "true",
        })).Location();
        string party = (await Post(client, "/Parties/Edit?role=customer", "/Parties/Edit", new()
        {
            ["Form.LegalName"] = "FreshBite Foods Pvt Ltd", ["Form.IsCustomer"] = "true", ["Form.Gstin"] = Gstin(customerState + "AAPCF1234K1Z"),
        })).Location();
        return new(client, tenantId, profileId, gst18, gst12, long.Parse(item.Split('/')[^1]), long.Parse(party.Split('/')[^1]));
    }

    public static Dictionary<string, string> Invoice(Setup s, string then = "draft", string rate = "4500", long? taxRateId = null, string qty = "2") => new()
    {
        ["then"] = then,
        ["Form.BusinessProfileId"] = s.ProfileId.ToString(),
        ["Form.PartyId"] = s.CustomerId.ToString(),
        ["Form.BuyerName"] = "FreshBite",
        ["Form.InvoiceDate"] = DateTime.UtcNow.AddHours(5.5).ToString("yyyy-MM-dd"),
        ["Form.Lines[0].OfferingId"] = s.ItemId.ToString(),
        ["Form.Lines[0].Description"] = "Tyre 145/80 R12",
        ["Form.Lines[0].HsnSacCode"] = "40111010",
        ["Form.Lines[0].Quantity"] = qty,
        ["Form.Lines[0].UnitCode"] = "pc",
        ["Form.Lines[0].Rate"] = rate,
        ["Form.Lines[0].TaxRateId"] = (taxRateId ?? s.Gst18).ToString(),
        // What a tampered browser might add: ignored, because the server computes every amount.
        ["Form.Lines[0].LineTotal"] = "1",
    };

    /// <summary>Issues an invoice for the setup's customer and returns its id.</summary>
    public static async Task<long> IssueAsync(Setup s, string rate = "4500", string qty = "2")
    {
        string view = (await Post(s.Client, "/Sales/Invoices/Edit", "/Sales/Invoices/Edit", Invoice(s, then: "issue", rate: rate, qty: qty))).Location();
        Assert.Matches(@"^/Sales/Invoices/View/\d+$", view);
        return long.Parse(view.Split('/')[^1]);
    }
}
