using System.Net;
using System.Net.Http.Headers;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Mvc.Testing;
using static BillingMadeEasy.Tests.Sql.WebFlow;

namespace BillingMadeEasy.Tests.Sql;

public partial class SqlBrandKitTests(SqlDatabaseFixture db) : IClassFixture<SqlDatabaseFixture>
{
    [GeneratedRegex("src=\"(/files/t\\d+/brands/[0-9a-f]+\\.png)\"")]
    private static partial Regex LogoSrc();

    private HttpClient Client() =>
        new SqlAppFactory(db).CreateClient(new WebApplicationFactoryClientOptions { AllowAutoRedirect = false });

    private async Task<(HttpClient Client, string BrandUrl)> BrandAsync()
    {
        string email = "b" + Guid.NewGuid().ToString("N")[..10] + "@test.in";
        await db.ProvisionAsync("T" + Guid.NewGuid().ToString("N")[..10], "Kit Co", email);
        var client = Client();
        await SignIn(client, email, SqlDatabaseFixture.Password);
        string party = (await Post(client, "/Parties/Edit?role=customer", "/Parties/Edit",
            new() { ["Form.LegalName"] = "Brand Owner Pvt Ltd", ["Form.IsCustomer"] = "true" })).Location();
        string brand = (await Post(client, party, party + "?handler=Brand", new() { ["Brand.BrandName"] = "FreshBite" })).Location();
        Assert.Matches(@"^/Parties/\d+/Brand/\d+$", brand);
        return (client, brand);
    }

    private static async Task<HttpResponseMessage> Upload(HttpClient client, string brandUrl, byte[] bytes, string name)
    {
        var form = new MultipartFormDataContent
        {
            { new StringContent(await Token(client, brandUrl)), "__RequestVerificationToken" },
            { new StringContent("1"), "variant" },
        };
        var file = new ByteArrayContent(bytes);
        file.Headers.ContentType = new MediaTypeHeaderValue("image/png");
        form.Add(file, "file", name);
        return await client.PostAsync(brandUrl + "?handler=Logo", form);
    }

    [SqlFact]
    public async Task Logo_upload_checks_the_bytes_and_stays_inside_the_business()
    {
        var (client, brand) = await BrandAsync();

        await Upload(client, brand, "MZ not really an image"u8.ToArray(), "evil.png");
        Assert.Contains("Use a PNG, JPG, WebP or SVG image.", await client.GetStringAsync(brand));

        await Upload(client, brand, await File.ReadAllBytesAsync(Path.Combine(AppContext.BaseDirectory, "Sql", "test-logo.png")), "logo.png");
        string page = await client.GetStringAsync(brand);
        Assert.Contains("Logo updated.", page);
        string src = LogoSrc().Match(page).Groups[1].Value;

        var mine = await client.GetAsync(src);
        Assert.Equal(HttpStatusCode.OK, mine.StatusCode);
        Assert.Equal("image/png", mine.Content.Headers.ContentType!.MediaType);

        var (stranger, _) = await BrandAsync();
        Assert.Equal(HttpStatusCode.NotFound, (await stranger.GetAsync(src)).StatusCode);
        Assert.Equal(HttpStatusCode.Redirect, (await Client().GetAsync(src)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync("/files/" + src.Split('/')[2] + "/../../secret.txt")).StatusCode);
    }

    [SqlFact]
    public async Task Kit_saves_named_colours_and_explains_a_bad_code()
    {
        var (client, brand) = await BrandAsync();

        var bad = await Post(client, brand, brand + "?handler=Kit", new() { ["Form.Colors[0].Hex"] = "reddish", ["Form.Colors[0].Name"] = "Primary" });
        Assert.Contains("isn&#x27;t a colour code", await bad.Content.ReadAsStringAsync());

        var ok = await Post(client, brand, brand + "?handler=Kit", new()
        {
            ["Form.Colors[0].Hex"] = "e63946", ["Form.Colors[0].Name"] = "Primary",
            ["Form.Colors[1].Hex"] = "#1d3557", ["Form.Colors[1].Name"] = "",
            ["Form.FontHeading"] = "Poppins", ["Form.Instagram"] = "@freshbite", ["Form.Guidelines"] = "Never on red.",
        });
        Assert.Equal(brand, ok.Location());

        string page = await client.GetStringAsync(brand);
        Assert.Contains("#E63946", page);
        Assert.Contains("Colour 2", page);
        Assert.Contains("instagram.com/freshbite", page);
        Assert.Contains("Never on red.", page);
    }
}
