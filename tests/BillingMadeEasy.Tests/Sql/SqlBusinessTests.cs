using System.Net;
using BillingMadeEasy.Core.Billing;
using Microsoft.AspNetCore.Mvc.Testing;
using static BillingMadeEasy.Tests.Sql.WebFlow;

namespace BillingMadeEasy.Tests.Sql;

public sealed class SqlBusinessTests(SqlDatabaseFixture db) : IClassFixture<SqlDatabaseFixture>
{
    private HttpClient Client() =>
        new SqlAppFactory(db).CreateClient(new WebApplicationFactoryClientOptions { AllowAutoRedirect = false });

    private static string Unique(string prefix) => prefix + Guid.NewGuid().ToString("N")[..10];

    private async Task<(HttpClient Client, long TenantId, string Profile)> OwnerAsync()
    {
        string email = Unique("b") + "@test.in";
        var (tenantId, _) = await db.ProvisionAsync(Unique("T"), "Sharma Traders", email);
        var client = Client();
        await SignIn(client, email, SqlDatabaseFixture.Password);
        long profileId = await db.ScalarAsync<long>("SELECT BusinessProfileId FROM tbl_BusinessProfiles WHERE TenantId = @tenantId AND IsDefault = 1", new { tenantId });
        return (client, tenantId, $"/Business/Profile/{profileId}");
    }

    private static Dictionary<string, string> Profile(string gstin = "", string state = "", string pan = "") => new()
    {
        ["Form.ProfileName"] = "Sharma Traders", ["Form.LegalName"] = "Sharma Traders Pvt Ltd",
        ["Form.Gstin"] = gstin, ["Form.StateCode"] = state, ["Form.Pan"] = pan, ["Form.RoundOffTotal"] = "true",
    };

    /// <summary>A GSTIN with a correct check character, built from its first 14.</summary>
    private static string Gstin(string first14)
    {
        const string cs = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        int sum = 0;
        for (int i = 0; i < 14; i++) { int v = cs.IndexOf(first14[i]) * (i % 2 == 1 ? 2 : 1); sum += v / 36 + v % 36; }
        return first14 + cs[(36 - sum % 36) % 36];
    }

    [SqlFact]
    public async Task A_new_business_can_invoice_on_day_one()
    {
        var (client, tenantId, profile) = await OwnerAsync();

        Assert.Equal("Sharma Traders", await db.ScalarAsync<string>("SELECT ProfileName FROM tbl_BusinessProfiles WHERE TenantId = @tenantId", new { tenantId }));
        Assert.Equal("INV", await db.ScalarAsync<string>("SELECT Prefix FROM tbl_NumberSeries WHERE TenantId = @tenantId AND DocumentType = 1 AND IsDefault = 1", new { tenantId }));

        string page = await client.GetStringAsync("/Business");
        Assert.Contains("Next invoice", page);
        Assert.Contains("Add address, state, logo, bank account", page);
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync(profile)).StatusCode);
    }

    [SqlFact]
    public async Task The_GSTIN_decides_state_and_PAN_and_disagreements_are_explained()
    {
        var (client, tenantId, profile) = await OwnerAsync();
        string gstin = Gstin("27AAPCS1234K1Z");

        var wrongState = await Post(client, profile, profile, Profile(gstin, "29"));
        Assert.Contains("registered in a different state", await wrongState.Content.ReadAsStringAsync());

        var wrongPan = await Post(client, profile, profile, Profile(gstin, "", "ABCDE1234F"));
        Assert.Contains("The PAN inside this GSTIN is AAPCS1234K", await wrongPan.Content.ReadAsStringAsync());

        Assert.Equal(profile, (await Post(client, profile, profile, Profile(gstin))).Location());
        Assert.Equal("27", await db.ScalarAsync<string>("SELECT StateCode FROM tbl_BusinessProfiles WHERE TenantId = @tenantId", new { tenantId }));
        Assert.Equal("AAPCS1234K", await db.ScalarAsync<string>("SELECT Pan FROM tbl_BusinessProfiles WHERE TenantId = @tenantId", new { tenantId }));
    }

    [SqlFact]
    public async Task Bank_details_are_checked_before_they_reach_an_invoice()
    {
        var (client, tenantId, profile) = await OwnerAsync();
        var bank = new Dictionary<string, string>
        {
            ["Bank.BankAccountId"] = "0", ["Bank.BankName"] = "HDFC Bank", ["Bank.AccountName"] = "Sharma Traders Pvt Ltd",
            ["Bank.AccountNumber"] = "50200012345678", ["Bank.Ifsc"] = "HDFC1234567", ["Bank.AccountType"] = "1",
        };
        Assert.Contains("An IFSC is 11 characters", await (await Post(client, profile, profile + "?handler=Bank", bank)).Content.ReadAsStringAsync());

        bank["Bank.Ifsc"] = "hdfc0001234";
        Assert.Equal(profile + "#payments", (await Post(client, profile, profile + "?handler=Bank", bank)).Location());
        Assert.Equal(1, await db.ScalarAsync<int>("SELECT COUNT(*) FROM tbl_BusinessBankAccounts WHERE TenantId = @tenantId AND IsDefault = 1 AND Ifsc = 'HDFC0001234'", new { tenantId }));

        Assert.Contains("already added", await (await Post(client, profile, profile + "?handler=Bank", bank)).Content.ReadAsStringAsync());
    }

    [SqlFact]
    public async Task Numbering_keeps_to_GST_rules()
    {
        var (client, tenantId, profile) = await OwnerAsync();
        var series = new Dictionary<string, string>
        {
            ["SeriesForm.SeriesId"] = "0", ["SeriesForm.DocumentType"] = "3", ["SeriesForm.SeriesName"] = "Credit notes",
            ["SeriesForm.Prefix"] = "SHARMACREDIT", ["SeriesForm.Separator"] = "-", ["SeriesForm.PadWidth"] = "4",
            ["SeriesForm.YearFormat"] = "1", ["SeriesForm.ResetYearly"] = "true", ["SeriesForm.StartFrom"] = "1",
        };
        Assert.Contains("at most 16 characters", await (await Post(client, profile, profile + "?handler=Series", series)).Content.ReadAsStringAsync());

        series["SeriesForm.Prefix"] = "INV";
        series["SeriesForm.DocumentType"] = "1";
        series["SeriesForm.YearFormat"] = "2";
        Assert.Contains("Another series already numbers", await (await Post(client, profile, profile + "?handler=Series", series)).Content.ReadAsStringAsync());

        // A second profile gets a prefix of its own, so the two can never print the same number.
        var second = Profile();
        second["Form.ProfileName"] = "Sharma Retail";
        string other = (await Post(client, "/Business/Profile", "/Business/Profile", second)).Location();
        Assert.Matches(@"^/Business/Profile/\d+$", other);
        long otherId = long.Parse(other.Split('/')[^1]);
        Assert.Equal("INV2", await db.ScalarAsync<string>("SELECT Prefix FROM tbl_NumberSeries WHERE BusinessProfileId = @otherId", new { otherId }));
    }

    [SqlFact]
    public async Task Issued_numbers_lock_the_format_and_the_database_formats_like_the_app()
    {
        var (client, tenantId, profile) = await OwnerAsync();
        long seriesId = await db.ScalarAsync<long>("SELECT SeriesId FROM tbl_NumberSeries WHERE TenantId = @tenantId AND DocumentType = 1", new { tenantId });
        await db.ExecuteAsync("EXEC dbo.usp_Number_Issue @TenantId = @tenantId, @DocumentType = 1, @DocumentDate = '2026-10-10', @SeriesId = @seriesId", new { tenantId, seriesId });

        var change = await Post(client, profile, profile + "?handler=Series", new()
        {
            ["SeriesForm.SeriesId"] = seriesId.ToString(), ["SeriesForm.DocumentType"] = "1", ["SeriesForm.SeriesName"] = "Tax invoices",
            ["SeriesForm.Prefix"] = "TI", ["SeriesForm.Separator"] = "-", ["SeriesForm.PadWidth"] = "4",
            ["SeriesForm.YearFormat"] = "2", ["SeriesForm.ResetYearly"] = "true", ["SeriesForm.StartFrom"] = "1", ["SeriesForm.IsDefault"] = "true",
        });
        Assert.Contains("documents already carry this format", await change.Content.ReadAsStringAsync());

        foreach (var (seq, pad, yf) in new[] { (7L, 4, (byte)2), (10000L, 4, (byte)2), (12L, 3, (byte)1), (5L, 2, (byte)0) })
            Assert.Equal(DocumentNumber.Format("INV", null, "-", yf, 2026, seq, pad),
                await db.ScalarAsync<string>("SELECT dbo.fn_FormatDocNumber('INV', NULL, '-', @yf, 2026, @seq, @pad)", new { yf, seq, pad }));
    }
}
