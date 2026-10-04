using System.Text.RegularExpressions;

namespace BillingMadeEasy.Tests.Sql;

/// <summary>Drives the real pages the way a browser does: antiforgery token, form post, redirects.</summary>
internal static partial class WebFlow
{
    [GeneratedRegex("name=\"__RequestVerificationToken\" type=\"hidden\" value=\"([^\"]+)\"")]
    private static partial Regex TokenPattern();

    public static async Task<HttpResponseMessage> SignIn(HttpClient client, string identifier, string password) =>
        await client.PostAsync("/Account/SignIn", Form(await Token(client, "/Account/SignIn"), new()
        {
            ["Identifier"] = identifier,
            ["Password"] = password,
        }));

    public static async Task<HttpResponseMessage> Choose(HttpClient client, long tenantId) =>
        await client.PostAsync("/Account/ChooseBusiness", Form(await Token(client, "/Account/ChooseBusiness"), new() { ["tenantId"] = tenantId.ToString() }));

    /// <summary>GETs <paramref name="page"/> for its token, then posts <paramref name="fields"/> to <paramref name="action"/>.</summary>
    public static async Task<HttpResponseMessage> Post(HttpClient client, string page, string action, Dictionary<string, string> fields) =>
        await client.PostAsync(action, Form(await Token(client, page), fields));

    public static FormUrlEncodedContent Form(string token, Dictionary<string, string> fields)
    {
        fields["__RequestVerificationToken"] = token;
        return new FormUrlEncodedContent(fields);
    }

    public static async Task<string> Token(HttpClient client, string path)
    {
        var response = await client.GetAsync(path);
        string html = await response.Content.ReadAsStringAsync();
        var match = TokenPattern().Match(html);
        Assert.True(match.Success, $"No antiforgery token on {path} ({(int)response.StatusCode})");
        return match.Groups[1].Value;
    }

    /// <summary>Redirect target as a local path, whether the server sent it absolute or relative.</summary>
    public static string Location(this HttpResponseMessage response)
    {
        var uri = response.Headers.Location ?? throw new InvalidOperationException($"Expected a redirect, got {(int)response.StatusCode}.");
        return uri.IsAbsoluteUri ? uri.PathAndQuery : uri.OriginalString;
    }
}
