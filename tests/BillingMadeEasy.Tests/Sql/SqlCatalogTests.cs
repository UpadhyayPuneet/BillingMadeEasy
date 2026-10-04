using System.Net;
using Microsoft.AspNetCore.Mvc.Testing;
using static BillingMadeEasy.Tests.Sql.WebFlow;

namespace BillingMadeEasy.Tests.Sql;

public sealed class SqlCatalogTests(SqlDatabaseFixture db) : IClassFixture<SqlDatabaseFixture>
{
    private HttpClient Client() =>
        new SqlAppFactory(db).CreateClient(new WebApplicationFactoryClientOptions { AllowAutoRedirect = false });

    private static string Unique(string prefix) => prefix + Guid.NewGuid().ToString("N")[..10];

    private async Task<(HttpClient Client, long TenantId)> OwnerAsync()
    {
        string email = Unique("c") + "@test.in";
        var (tenantId, _) = await db.ProvisionAsync(Unique("T"), "Wheels & Co", email);
        var client = Client();
        await SignIn(client, email, SqlDatabaseFixture.Password);
        return (client, tenantId);
    }

    private Task<long> RateAsync(long tenantId, string name) =>
        db.ScalarAsync<long>("SELECT TaxRateId FROM tbl_TaxRates WHERE TenantId = @tenantId AND TaxName = @name", new { tenantId, name });

    private static Dictionary<string, string> Product(string name, long taxRateId, string hsn = "40111010") => new()
    {
        ["Form.OfferingType"] = "1",
        ["Form.OfferingName"] = name,
        ["Form.TaxRateId"] = taxRateId.ToString(),
        ["Form.HsnSacCode"] = hsn,
        ["Form.DefaultPrice"] = "4500",
        ["Form.IsPriceInclusive"] = "true",
        ["Form.DefaultCost"] = "3217",
        ["Form.IsSellable"] = "true",
        ["Form.BrandName"] = "MRF",
    };

    [SqlFact]
    public async Task A_new_business_starts_with_GST_rates_and_units()
    {
        var (_, tenantId) = await OwnerAsync();

        Assert.Equal("GST 18%", await db.ScalarAsync<string>("SELECT TaxName FROM tbl_TaxRates WHERE TenantId = @tenantId AND IsDefault = 1", new { tenantId }));
        Assert.True(await db.ScalarAsync<int>("SELECT COUNT(*) FROM tbl_TaxRates WHERE TenantId = @tenantId", new { tenantId }) >= 11);
        Assert.Equal("PCS", await db.ScalarAsync<string>("SELECT UqcCode FROM tbl_Units WHERE TenantId = @tenantId AND UnitCode = 'pc'", new { tenantId }));

        // Running the seeding again adds nothing.
        await db.ExecuteAsync("EXEC dbo.usp_Catalog_EnsureDefaults @TenantId = @tenantId, @Silent = 1", new { tenantId });
        Assert.Equal(1, await db.ScalarAsync<int>("SELECT COUNT(*) FROM tbl_TaxRates WHERE TenantId = @tenantId AND TaxName = 'GST 18%'", new { tenantId }));
    }

    [SqlFact]
    public async Task A_product_is_checked_saved_and_reads_back_as_typed()
    {
        var (client, tenantId) = await OwnerAsync();
        long gst18 = await RateAsync(tenantId, "GST 18%");

        var badHsn = await Post(client, "/Catalog/Item?type=product", "/Catalog/Item", Product("Tyre 145/80 R12", gst18, hsn: "998361"));
        Assert.Equal(HttpStatusCode.OK, badHsn.StatusCode);
        Assert.Contains("Codes starting 99 are for services", await badHsn.Content.ReadAsStringAsync());

        var form = Product("Tyre 145/80 R12", gst18);
        form["Form.Barcode"] = "8901234567890";
        string item = (await Post(client, "/Catalog/Item?type=product", "/Catalog/Item", form)).Location();
        Assert.Matches(@"^/Catalog/Item/\d+$", item);

        string page = await client.GetStringAsync(item);
        Assert.Contains("Added Tyre 145/80 R12.", page);
        Assert.Contains("value=\"4500\"", page);          // not 4500.0000
        Assert.Contains("value=\"3217\"", page);
        Assert.Equal(1, await db.ScalarAsync<int>("SELECT COUNT(*) FROM tbl_ProductBrands WHERE TenantId = @tenantId AND BrandName = 'MRF'", new { tenantId }));

        // "M.R.F." is the same brand, and a second item can't take the same barcode.
        var second = Product("Tyre 155/80 R13", gst18);
        second["Form.BrandName"] = "M.R.F.";
        second["Form.Barcode"] = "8901234567890";
        var clash = await Post(client, "/Catalog/Item?type=product", "/Catalog/Item", second);
        Assert.Contains("That barcode is already on Tyre 145/80 R12", await clash.Content.ReadAsStringAsync());
        second["Form.Barcode"] = "8901234567891";
        Assert.Matches(@"^/Catalog/Item/\d+$", (await Post(client, "/Catalog/Item?type=product", "/Catalog/Item", second)).Location());
        Assert.Equal(1, await db.ScalarAsync<int>("SELECT COUNT(*) FROM tbl_ProductBrands WHERE TenantId = @tenantId", new { tenantId }));
    }

    [SqlFact]
    public async Task A_pure_agent_reimbursement_carries_no_GST()
    {
        var (client, tenantId) = await OwnerAsync();
        long gst18 = await RateAsync(tenantId, "GST 18%");

        var asProduct = Product("Stamp duty", gst18, hsn: "");
        asProduct["Form.IsPureAgent"] = "true";
        Assert.Contains("Only a service can be a pure-agent reimbursement",
            await (await Post(client, "/Catalog/Item?type=product", "/Catalog/Item", asProduct)).Content.ReadAsStringAsync());

        var fee = new Dictionary<string, string>
        {
            ["Form.OfferingType"] = "2", ["Form.OfferingName"] = "ROC filing fee", ["Form.HsnSacCode"] = "998399",
            ["Form.TaxRateId"] = gst18.ToString(), ["Form.IsPureAgent"] = "true", ["Form.DefaultPrice"] = "1500", ["Form.IsSellable"] = "true",
        };
        string item = (await Post(client, "/Catalog/Item?type=service", "/Catalog/Item", fee)).Location();
        long id = long.Parse(item.Split('/')[^1]);
        Assert.Equal(0, await db.ScalarAsync<int>("SELECT COUNT(*) FROM tbl_Offerings WHERE OfferingId = @id AND TaxRateId IS NOT NULL", new { id }));
        Assert.Contains("at cost", await client.GetStringAsync("/Catalog"));
    }

    [SqlFact]
    public async Task Customer_prices_are_set_and_removed()
    {
        var (client, tenantId) = await OwnerAsync();
        string item = (await Post(client, "/Catalog/Item?type=product", "/Catalog/Item", Product("Tyre", await RateAsync(tenantId, "GST 18%")))).Location();
        string party = (await Post(client, "/Parties/Edit?role=customer", "/Parties/Edit",
            new() { ["Form.LegalName"] = "FreshBite Foods Pvt Ltd", ["Form.IsCustomer"] = "true" })).Location();
        long partyId = long.Parse(party.Split('/')[^1]);

        var found = await client.GetStringAsync(item + "?handler=Customers&q=fresh");
        Assert.Contains($"\"id\":{partyId}", found);

        var saved = await Post(client, item, item + "?handler=CustomerPrice", new() { ["partyId"] = partyId.ToString(), ["price"] = "4200", ["minQuantity"] = "1" });
        Assert.Equal(item + "#customer-prices", saved.Location());
        string page = await client.GetStringAsync(item);
        Assert.Contains("Customer price saved.", page);
        Assert.Contains("₹4,200", page);

        long priceItemId = await db.ScalarAsync<long>("""
            SELECT i.PriceListItemId FROM tbl_PriceListItems i JOIN tbl_PriceLists l ON l.PriceListId = i.PriceListId
             WHERE l.TenantId = @tenantId AND l.PartyId = @partyId
            """, new { tenantId, partyId });
        await Post(client, item, item + "?handler=RemovePrice", new() { ["itemId"] = priceItemId.ToString() });
        Assert.Contains("Everyone pays the standard price", await client.GetStringAsync(item));
    }

    [SqlFact]
    public async Task Someone_without_cost_access_never_sees_or_changes_it()
    {
        var (owner, tenantId) = await OwnerAsync();
        string item = (await Post(owner, "/Catalog/Item?type=product", "/Catalog/Item", Product("Tyre", await RateAsync(tenantId, "GST 18%")))).Location();

        string email = Unique("a") + "@test.in";
        var (_, userId) = await db.ProvisionAsync(Unique("Y"), "Accountant's own", email);
        await db.AddMemberAsync(tenantId, userId, "ACCOUNTANT");
        var accountant = Client();
        await SignIn(accountant, email, SqlDatabaseFixture.Password);
        await Choose(accountant, tenantId);

        string page = await accountant.GetStringAsync(item);
        Assert.Contains("value=\"4500\"", page);          // price: yes
        Assert.DoesNotContain("3217", page);             // cost: no
        Assert.DoesNotContain("Form.DefaultCost", page);

        // Viewing isn't editing: a crafted post is refused and nothing changes.
        var form = Product("Renamed", 0);
        form["Form.DefaultCost"] = "1";
        var post = await accountant.PostAsync(item, Form(await Token(accountant, item), form));
        Assert.StartsWith("/Account/Denied", post.Location());
        Assert.Equal(3217m, await db.ScalarAsync<decimal>("SELECT DefaultCost FROM tbl_Offerings WHERE OfferingName = 'Tyre' AND TenantId = @tenantId", new { tenantId }));
    }
}
