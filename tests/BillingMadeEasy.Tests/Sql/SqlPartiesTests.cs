using System.Net;
using Microsoft.AspNetCore.Mvc.Testing;
using static BillingMadeEasy.Tests.Sql.WebFlow;

namespace BillingMadeEasy.Tests.Sql;

/// <summary>Customers and suppliers through the real pages and usp_Party* procedures.</summary>
public class SqlPartiesTests(SqlDatabaseFixture db) : IClassFixture<SqlDatabaseFixture>
{
    private HttpClient Client() =>
        new SqlAppFactory(db).CreateClient(new WebApplicationFactoryClientOptions { AllowAutoRedirect = false });

    private static string Unique(string prefix) => prefix + Guid.NewGuid().ToString("N")[..10];

    private async Task<(HttpClient Client, long TenantId, long UserId)> OwnerAsync()
    {
        string email = Unique("o") + "@test.in";
        var (tenantId, userId) = await db.ProvisionAsync(Unique("T"), "Biz " + Unique(""), email);
        var client = Client();
        await SignIn(client, email, SqlDatabaseFixture.Password);
        return (client, tenantId, userId);
    }

    private static Task<HttpResponseMessage> CreateParty(HttpClient client, Dictionary<string, string> fields) =>
        Post(client, "/Parties/Edit?role=customer", "/Parties/Edit", fields);

    [SqlFact]
    public async Task New_customer_with_gstin_gets_pan_state_and_a_default_branch()
    {
        var (client, tenantId, _) = await OwnerAsync();

        var response = await CreateParty(client, new()
        {
            ["Form.Gstin"] = "29aagcb7383j1z4",
            ["Form.AddressLine1"] = "100 MG Road",
            ["Form.City"] = "Bengaluru",
            ["Form.LegalName"] = "Bright Labs Private Limited",
            ["Form.PartyType"] = "2",
            ["Form.IsCustomer"] = "true",
            ["Form.CustomerTermDays"] = "15",
        });

        Assert.Equal(HttpStatusCode.Redirect, response.StatusCode);
        Assert.StartsWith("/Parties/View/", response.Location());

        long partyId = long.Parse(response.Location().Split('/').Last());
        Assert.Equal("AAGCB7383J", await db.ScalarAsync<string>("SELECT TaxIdNumber FROM tbl_Parties WHERE PartyId = @partyId AND TenantId = @tenantId", new { partyId, tenantId }));
        Assert.Equal("29", await db.ScalarAsync<string>(
            "SELECT a.StateCode FROM tbl_PartyLocations l JOIN tbl_PartyAddresses a ON a.PartyAddressId = l.AddressId WHERE l.PartyId = @partyId AND l.IsDefault = 1 AND l.Gstin = '29AAGCB7383J1Z4'", new { partyId }));

        string page = await client.GetStringAsync(response.Location());
        Assert.Contains("Bright Labs Private Limited", page);
        Assert.Contains("15 days", page);
    }

    [SqlFact]
    public async Task A_gstin_already_on_file_is_refused_before_anything_is_created()
    {
        var (client, tenantId, _) = await OwnerAsync();
        var first = await CreateParty(client, new() { ["Form.Gstin"] = "24AAACC1206D1ZM", ["Form.LegalName"] = "Original Co", ["Form.IsCustomer"] = "true" });
        Assert.Equal(HttpStatusCode.Redirect, first.StatusCode);

        var second = await CreateParty(client, new() { ["Form.Gstin"] = "24AAACC1206D1ZM", ["Form.LegalName"] = "Copy Co", ["Form.IsCustomer"] = "true" });

        Assert.Equal(HttpStatusCode.OK, second.StatusCode);
        Assert.Contains("This GSTIN already belongs to Original Co.", await second.Content.ReadAsStringAsync());
        Assert.Equal(0, await db.ScalarAsync<int>("SELECT COUNT(*) FROM tbl_Parties WHERE TenantId = @tenantId AND LegalName = 'Copy Co'", new { tenantId }));
    }

    [SqlFact]
    public async Task Bad_input_is_explained_field_by_field()
    {
        var (client, _, _) = await OwnerAsync();

        var response = await CreateParty(client, new()
        {
            ["Form.Gstin"] = "27AAPFU0939F1ZW",
            ["Form.TaxIdNumber"] = "ABC",
            ["Form.LegalName"] = "",
        });
        string html = await response.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Contains("Enter the name.", html);
        Assert.Contains("Mark them as a customer, a supplier, or both.", html);
        Assert.Contains("A PAN is 10 characters", html);
        Assert.Contains("The last character doesn&#x27;t match", html);
    }

    [SqlFact]
    public async Task Another_business_cannot_see_or_change_the_party()
    {
        var (owner, _, _) = await OwnerAsync();
        var created = await CreateParty(owner, new() { ["Form.LegalName"] = "Private Customer", ["Form.IsCustomer"] = "true" });
        string url = created.Location();
        long partyId = long.Parse(url.Split('/').Last());

        var (stranger, _, _) = await OwnerAsync();
        Assert.Equal(HttpStatusCode.NotFound, (await stranger.GetAsync(url)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await stranger.GetAsync($"/Parties/Edit/{partyId}")).StatusCode);
        Assert.DoesNotContain("Private Customer", await stranger.GetStringAsync("/Parties?q=Private"));
    }

    [SqlFact]
    public async Task A_viewer_can_look_but_not_change()
    {
        var (owner, tenantId, _) = await OwnerAsync();
        var created = await CreateParty(owner, new() { ["Form.LegalName"] = "Watched Co", ["Form.IsCustomer"] = "true" });
        string url = created.Location();

        string viewerEmail = Unique("v") + "@test.in";
        var (_, viewerId) = await db.ProvisionAsync(Unique("V"), "Viewer's own", viewerEmail);
        await db.AddMemberAsync(tenantId, viewerId, "VIEWER");

        var viewer = Client();
        await SignIn(viewer, viewerEmail, SqlDatabaseFixture.Password);
        await Choose(viewer, tenantId);

        string page = await viewer.GetStringAsync(url);
        Assert.Contains("Watched Co", page);
        Assert.DoesNotContain("data-key=\"e\"", page);
        Assert.StartsWith("/Account/Denied", (await viewer.GetAsync("/Parties/Edit?role=customer")).Location());

        // A crafted post to a handler is refused too, not just hidden in the page.
        var post = await viewer.PostAsync(url + "?handler=Contact",
            Form(await Token(viewer, url), new() { ["Contact.ContactName"] = "Sneaky" }));
        Assert.StartsWith("/Account/Denied", post.Location());
        Assert.Equal(0, await db.ScalarAsync<int>("SELECT COUNT(*) FROM tbl_PartyContacts WHERE ContactName = 'Sneaky'"));
    }

    [SqlFact]
    public async Task Branches_contacts_and_status_round_trip()
    {
        var (client, _, _) = await OwnerAsync();
        string url = (await CreateParty(client, new() { ["Form.LegalName"] = "Round Trip Traders", ["Form.IsCustomer"] = "true", ["Form.IsSupplier"] = "true" })).Location();

        // GSTIN state must match the address state.
        var mismatch = await Post(client, url, url + "?handler=Location", new()
        {
            ["Location.LocationName"] = "Jaipur", ["Location.Gstin"] = "27AAPFU0939F1ZV", ["Location.StateCode"] = "08",
        });
        Assert.Contains("registered in Maharashtra but the address is in Rajasthan", await mismatch.Content.ReadAsStringAsync());

        var branch = await Post(client, url, url + "?handler=Location", new()
        {
            ["Location.LocationName"] = "Pune", ["Location.Gstin"] = "27AAPFU0939F1ZV", ["Location.AddressLine1"] = "FC Road", ["Location.City"] = "Pune",
        });
        Assert.Equal(url, branch.Location());

        var contact = await Post(client, url, url + "?handler=Contact", new()
        {
            ["Contact.ContactName"] = "Asha Rao", ["Contact.Mobile"] = "9000000001", ["Contact.IsPrimary"] = "true",
        });
        Assert.Equal(url, contact.Location());

        var hold = await Post(client, url, url + "?handler=Status", new() { ["status"] = "2" });
        Assert.Equal(url, hold.Location());

        string page = await client.GetStringAsync(url);
        Assert.Contains("Pune", page);
        Assert.Contains("27AAPFU0939F1ZV", page);
        Assert.Contains("Asha Rao", page);
        Assert.Contains("On hold", page);
        Assert.Contains("On hold. New sales and purchases are blocked", page);
    }
}
