using System.Net;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Mvc.Testing;
using static BillingMadeEasy.Tests.Sql.WebFlow;

namespace BillingMadeEasy.Tests.Sql;

/// <summary>Forgotten passwords, resets, changes and forced changes, end to end.</summary>
public sealed partial class SqlPasswordTests(SqlDatabaseFixture db) : IClassFixture<SqlDatabaseFixture>, IDisposable
{
    private readonly string _mail = Directory.CreateTempSubdirectory("bme-mail-").FullName;

    [GeneratedRegex(@"http://localhost/Account/Reset\?u=[0-9a-f]+&t=[A-Za-z0-9_\-%]+")]
    private static partial Regex ResetLink();

    public void Dispose() => Directory.Delete(_mail, recursive: true);

    private HttpClient Client() =>
        new SqlAppFactory(db, _mail).CreateClient(new WebApplicationFactoryClientOptions { AllowAutoRedirect = false });

    private async Task<string> OwnerAsync()
    {
        string email = "p" + Guid.NewGuid().ToString("N")[..10] + "@test.in";
        await db.ProvisionAsync("T" + Guid.NewGuid().ToString("N")[..10], "Pw Co", email);
        return email;
    }

    private string[] MailsTo(string email) =>
        Directory.GetFiles(_mail, "*AUTH_PASSWORD_RESET*.eml")
            .Where(f => File.ReadAllText(f).Contains(email, StringComparison.OrdinalIgnoreCase))
            .ToArray();

    private string LinkFrom(string file)
    {
        // Undo quoted-printable soft breaks and =3D before looking for the link.
        string text = Regex.Replace(File.ReadAllText(file), "=\r?\n", "").Replace("=3D", "=");
        return new Uri(ResetLink().Match(text).Value).PathAndQuery;
    }

    [SqlFact]
    public async Task Forgot_says_the_same_thing_whether_or_not_the_account_exists()
    {
        var client = Client();
        var unknown = await Post(client, "/Account/Forgot", "/Account/Forgot", new() { ["Email"] = "nobody-" + Guid.NewGuid().ToString("N")[..6] + "@test.in" });
        string email = await OwnerAsync();
        var known = await Post(client, "/Account/Forgot", "/Account/Forgot", new() { ["Email"] = email });

        string a = await unknown.Content.ReadAsStringAsync(), b = await known.Content.ReadAsStringAsync();
        Assert.Contains("Check your email", a);
        Assert.Contains("Check your email", b);
        Assert.Single(MailsTo(email));
    }

    [SqlFact]
    public async Task Reset_replaces_the_password_signs_out_everywhere_and_the_link_dies()
    {
        string email = await OwnerAsync();
        var elsewhere = Client();
        await SignIn(elsewhere, email, SqlDatabaseFixture.Password);
        Assert.Equal(HttpStatusCode.OK, (await elsewhere.GetAsync("/")).StatusCode);

        var client = Client();
        await Post(client, "/Account/Forgot", "/Account/Forgot", new() { ["Email"] = email });
        // A second request inside the reuse window sends nothing new; the first link still works.
        await Post(client, "/Account/Forgot", "/Account/Forgot", new() { ["Email"] = email });
        string mail = Assert.Single(MailsTo(email));
        string link = LinkFrom(mail);

        var reused = await Post(client, link, link, new() { ["Password"] = SqlDatabaseFixture.Password, ["Confirm"] = SqlDatabaseFixture.Password });
        Assert.Contains("used that password recently", await reused.Content.ReadAsStringAsync());

        var done = await Post(client, link, link, new() { ["Password"] = "Monsoon ledger 2026", ["Confirm"] = "Monsoon ledger 2026" });
        Assert.StartsWith("/Account/SignIn", done.Location());
        Assert.Contains("reset=1", done.Location());

        Assert.StartsWith("/Account/SignIn", (await elsewhere.GetAsync("/")).Location());
        Assert.Contains("don&#x27;t match", await (await SignIn(Client(), email, SqlDatabaseFixture.Password)).Content.ReadAsStringAsync());
        Assert.Equal("/", (await SignIn(Client(), email, "Monsoon ledger 2026")).Location());
        Assert.Contains("That link didn't work", await Client().GetStringAsync(link));
    }

    [SqlFact]
    public async Task Changing_your_password_keeps_you_in_here_and_signs_out_other_devices()
    {
        string email = await OwnerAsync();
        var phone = Client();
        await SignIn(phone, email, SqlDatabaseFixture.Password);
        var laptop = Client();
        await SignIn(laptop, email, SqlDatabaseFixture.Password);

        var wrong = await Post(laptop, "/Account/Password", "/Account/Password",
            new() { ["Current"] = "not it", ["Password"] = "Monsoon ledger 2026", ["Confirm"] = "Monsoon ledger 2026" });
        Assert.Contains("That isn&#x27;t your current password.", await wrong.Content.ReadAsStringAsync());

        var changed = await Post(laptop, "/Account/Password", "/Account/Password",
            new() { ["Current"] = SqlDatabaseFixture.Password, ["Password"] = "Monsoon ledger 2026", ["Confirm"] = "Monsoon ledger 2026" });
        Assert.Equal("/Account/Password?done=true", changed.Location());

        Assert.Equal(HttpStatusCode.OK, (await laptop.GetAsync("/Parties")).StatusCode);
        Assert.StartsWith("/Account/SignIn", (await phone.GetAsync("/")).Location());
    }

    [SqlFact]
    public async Task A_flagged_account_must_choose_a_new_password_first()
    {
        string email = await OwnerAsync();
        await db.ExecuteAsync("UPDATE tbl_Users SET MustChangePassword = 1 WHERE Email = @email", new { email });

        var client = Client();
        await SignIn(client, email, SqlDatabaseFixture.Password);
        Assert.Equal("/Account/Password?required=1", (await client.GetAsync("/Parties")).Location());

        string page = await client.GetStringAsync("/Account/Password?required=1");
        Assert.Contains("Choose your own password", page);
        Assert.DoesNotContain("name=\"Current\"", page);

        var changed = await Post(client, "/Account/Password", "/Account/Password",
            new() { ["Password"] = "Monsoon ledger 2026", ["Confirm"] = "Monsoon ledger 2026" });
        Assert.Equal("/Account/Password?done=true", changed.Location());
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/Parties")).StatusCode);
        Assert.False(await db.ScalarAsync<bool>("SELECT MustChangePassword FROM tbl_Users WHERE Email = @email", new { email }));
    }
}
