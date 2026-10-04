using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.RegularExpressions;
using BillingMadeEasy.Core.Modules;
using BillingMadeEasy.Web.Infrastructure.Demo;
using BillingMadeEasy.Web.Infrastructure.Modules;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.Routing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;

namespace BillingMadeEasy.Tests.Web;

/// <summary>Inventory is on for Sharma Tyres (tenant 2) and off for Yenetch (tenant 1) in the demo data.</summary>
public sealed class ProbeInventoryModule : IAppModule
{
    public string Key => ModuleKeys.Inventory;
    public string? PagesFolder => null;
    public IEnumerable<NavItem> Navigation => [new("Stock", "/Stock", "inventory_2", Shortcut: "s")];
    public void MapEndpoints(IEndpointRouteBuilder api) => api.MapGet("/inventory/ping", () => "pong");
}

public sealed class AppFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Development");
        builder.ConfigureTestServices(services => services.AddSingleton<IAppModule, ProbeInventoryModule>());
    }
}

public class ShellTests(AppFactory factory) : IClassFixture<AppFactory>
{
    private HttpClient Client() => factory.CreateClient(new WebApplicationFactoryClientOptions { AllowAutoRedirect = false });

    [Fact]
    public async Task Anonymous_pages_redirect_to_sign_in()
    {
        var response = await Client().GetAsync("/");

        Assert.Equal(HttpStatusCode.Redirect, response.StatusCode);
        Assert.StartsWith("/Account/SignIn", response.Headers.Location!.PathAndQuery);
    }

    [Fact]
    public async Task Business_picker_is_not_anonymous()
    {
        var response = await Client().GetAsync("/Account/ChooseBusiness");

        Assert.Equal(HttpStatusCode.Redirect, response.StatusCode);
        Assert.StartsWith("/Account/SignIn", response.Headers.Location!.PathAndQuery);
    }

    [Fact]
    public async Task Anonymous_api_gets_401_not_a_redirect()
    {
        var response = await Client().GetAsync("/api/core/gstin/27AAPFU0939F1ZV");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Health_and_security_headers()
    {
        var response = await Client().GetAsync("/health");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Contains("frame-ancestors 'none'", response.Headers.GetValues("Content-Security-Policy").Single());
        Assert.Equal("nosniff", response.Headers.GetValues("X-Content-Type-Options").Single());
    }

    [Fact]
    public async Task Wrong_password_gets_one_generic_message()
    {
        var client = Client();
        var response = await PostSignIn(client, DemoData.Email, "nope");
        string html = await response.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Contains("That email and password don&#x27;t match.", html);
    }

    [Fact]
    public async Task Sign_in_choose_business_and_use_the_app()
    {
        var client = Client();
        var signIn = await PostSignIn(client, DemoData.Email, DemoData.Password);
        Assert.Equal(HttpStatusCode.Redirect, signIn.StatusCode);
        Assert.StartsWith("/Account/ChooseBusiness", signIn.Headers.Location!.OriginalString);

        // Signed in as a person, no business yet: app pages send you to the picker.
        var early = await client.GetAsync("/");
        Assert.StartsWith("/Account/ChooseBusiness", early.Headers.Location!.OriginalString);

        await ChooseBusiness(client, 1);

        var home = await client.GetAsync("/");
        string html = await home.Content.ReadAsStringAsync();
        Assert.Equal(HttpStatusCode.OK, home.StatusCode);
        Assert.Contains("Yenetch Technologies", html);

        var gstin = await client.GetFromJsonAsync<JsonElement>("/api/core/gstin/27AAPFU0939F1ZV");
        Assert.True(gstin.GetProperty("valid").GetBoolean());
        Assert.Equal("Maharashtra", gstin.GetProperty("state").GetString());
    }

    [Fact]
    public async Task Module_endpoints_follow_the_tenant_entitlement()
    {
        var client = Client();
        await PostSignIn(client, DemoData.Email, DemoData.Password);

        await ChooseBusiness(client, 1);
        var off = await client.GetAsync("/api/inventory/ping");
        Assert.Equal(HttpStatusCode.Forbidden, off.StatusCode);
        Assert.Contains("/Plan?need=inventory", await off.Content.ReadAsStringAsync());
        Assert.DoesNotContain("g s", await (await client.GetAsync("/")).Content.ReadAsStringAsync());

        await ChooseBusiness(client, 2);
        var on = await client.GetAsync("/api/inventory/ping");
        Assert.Equal(HttpStatusCode.OK, on.StatusCode);
        Assert.Equal("pong", await on.Content.ReadAsStringAsync());
        Assert.Contains("g s", await (await client.GetAsync("/")).Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task A_tampered_tenant_id_is_refused()
    {
        var client = Client();
        await PostSignIn(client, DemoData.Email, DemoData.Password);

        var response = await ChooseBusiness(client, 999);
        Assert.Equal(HttpStatusCode.Redirect, response.StatusCode);
        Assert.StartsWith("/Account/Denied", response.Headers.Location!.PathAndQuery);
        Assert.StartsWith("/Account/ChooseBusiness", (await client.GetAsync("/")).Headers.Location!.OriginalString);
    }

    private static async Task<HttpResponseMessage> PostSignIn(HttpClient client, string identifier, string password)
    {
        string token = await AntiforgeryToken(client, "/Account/SignIn");
        return await client.PostAsync("/Account/SignIn", new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["Identifier"] = identifier,
            ["Password"] = password,
            ["__RequestVerificationToken"] = token,
        }));
    }

    private static async Task<HttpResponseMessage> ChooseBusiness(HttpClient client, long tenantId)
    {
        string token = await AntiforgeryToken(client, "/Account/ChooseBusiness");
        return await client.PostAsync("/Account/ChooseBusiness", new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["tenantId"] = tenantId.ToString(),
            ["__RequestVerificationToken"] = token,
        }));
    }

    private static async Task<string> AntiforgeryToken(HttpClient client, string path)
    {
        string html = await client.GetStringAsync(path);
        var match = Regex.Match(html, "name=\"__RequestVerificationToken\" type=\"hidden\" value=\"([^\"]+)\"");
        Assert.True(match.Success, $"No antiforgery token on {path}");
        return match.Groups[1].Value;
    }
}
