using System.Text.RegularExpressions;
using System.Net;
using System.Security.Cryptography;
using BillingMadeEasy.Core.Modules;
using BillingMadeEasy.Core.Security;
using BillingMadeEasy.Data;
using static BillingMadeEasy.Tests.Sql.WebFlow;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;

namespace BillingMadeEasy.Tests.Sql;

public sealed class SqlAppFactory(SqlDatabaseFixture db) : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Development");
        // UseSetting, not ConfigureAppConfiguration: Program reads these before the host is built.
        builder.UseSetting("Auth:Provider", "Sql");
        builder.UseSetting("Auth:SignInRequestsPerMinute", "10000");
        builder.UseSetting("ConnectionStrings:BillingMadeEasy", db.ConnectionString);
        builder.UseSetting("Email:Mode", "Disabled");   // invite flows fall back to the share link
    }
}

/// <summary>Sign-in end to end: real HTTP pipeline, real usp_Auth_* procedures, a fresh database.</summary>
public class SqlSignInTests(SqlDatabaseFixture db) : IClassFixture<SqlDatabaseFixture>
{
    private static int _seq;

    private HttpClient Client() =>
        new SqlAppFactory(db).CreateClient(new WebApplicationFactoryClientOptions { AllowAutoRedirect = false });

    private static string UniqueEmail() => $"owner{Interlocked.Increment(ref _seq)}.{Guid.NewGuid():N}"[..20] + "@test.in";

    private async Task<string> SoloOwnerAsync(byte status = 2)
    {
        string email = UniqueEmail();
        string code = "T" + Guid.NewGuid().ToString("N")[..10];
        await db.ProvisionAsync(code, "Solo " + code, email, status);
        return email;
    }

    [SqlFact]
    public async Task Owner_of_one_business_lands_straight_on_home()
    {
        string email = await SoloOwnerAsync();
        var client = Client();

        var response = await SignIn(client, email, SqlDatabaseFixture.Password);
        string body = await response.Content.ReadAsStringAsync();
        Assert.True(response.StatusCode == HttpStatusCode.Redirect, Regex.Match(body, "notice[^>]*>([^<]*)").Groups[1].Value + " | " + Regex.Match(body, "field-error[^>]*>([^<]+)").Groups[1].Value);
        Assert.Equal("/", response.Location());

        var home = await client.GetAsync("/");
        Assert.Equal(HttpStatusCode.OK, home.StatusCode);
        Assert.Contains("Solo ", await home.Content.ReadAsStringAsync());

        long tenantOnSession = await db.ScalarAsync<long>(
            "SELECT TOP 1 s.TenantId FROM tbl_UserSessions s JOIN tbl_Users u ON u.UserId = s.UserId WHERE u.Email = @email AND s.EndedAtUtc IS NULL", new { email });
        Assert.True(tenantOnSession > 0);
    }

    [SqlFact]
    public async Task Wrong_password_is_generic_and_the_ladder_blocks_after_five()
    {
        string email = await SoloOwnerAsync();
        var client = Client();

        for (int i = 0; i < 4; i++)
            Assert.Contains("That email and password don&#x27;t match.", await (await SignIn(client, email, "wrong")).Content.ReadAsStringAsync());

        Assert.Contains("Too many attempts", await (await SignIn(client, email, "wrong")).Content.ReadAsStringAsync());

        // Even the right password is refused while the block holds.
        var blocked = await SignIn(client, email, SqlDatabaseFixture.Password);
        Assert.Equal(HttpStatusCode.OK, blocked.StatusCode);
        Assert.Contains("Too many attempts", await blocked.Content.ReadAsStringAsync());
    }

    [SqlFact]
    public async Task Unknown_identity_reads_the_same_as_a_wrong_password()
    {
        var html = await (await SignIn(Client(), "nobody@nowhere.in", "whatever")).Content.ReadAsStringAsync();
        Assert.Contains("That email and password don&#x27;t match.", html);
    }

    [SqlFact]
    public async Task Person_in_two_businesses_picks_one_and_cannot_pick_someone_elses()
    {
        string email = UniqueEmail();
        var (first, _) = await db.ProvisionAsync("A" + Guid.NewGuid().ToString("N")[..10], "Alpha Traders", email);
        var (second, _) = await db.ProvisionAsync("B" + Guid.NewGuid().ToString("N")[..10], "Beta Services", email);
        var (stranger, _) = await db.ProvisionAsync("C" + Guid.NewGuid().ToString("N")[..10], "Someone Else", UniqueEmail());

        var client = Client();
        var signIn = await SignIn(client, email, SqlDatabaseFixture.Password);
        Assert.StartsWith("/Account/ChooseBusiness", signIn.Location());

        string picker = await client.GetStringAsync("/Account/ChooseBusiness");
        Assert.Contains("Alpha Traders", picker);
        Assert.Contains("Beta Services", picker);
        Assert.DoesNotContain("Someone Else", picker);

        var denied = await Choose(client, stranger);
        Assert.StartsWith("/Account/Denied", denied.Location());
        Assert.Equal(1, await db.ScalarAsync<int>("SELECT COUNT(*) FROM tbl_AuditLog WHERE ActionCode = 'Auth.Tenant.Denied' AND EntityId = @stranger", new { stranger }));

        Assert.Equal("/", (await Choose(client, second)).Location());
        Assert.Contains("Beta Services", await client.GetStringAsync("/"));
        Assert.Equal("/", (await Choose(client, first)).Location());
        Assert.Contains("Alpha Traders", await client.GetStringAsync("/"));
    }

    [SqlFact]
    public async Task Sign_out_ends_the_server_session_so_a_copied_cookie_is_useless()
    {
        string email = await SoloOwnerAsync();
        var client = Client();
        var signIn = await SignIn(client, email, SqlDatabaseFixture.Password);
        string cookie = AuthCookie(signIn);

        await client.PostAsync("/Account/SignOut", Form(await Token(client, "/"), []));

        // Replay the cookie captured before sign-out from a fresh client.
        var replay = Client();
        replay.DefaultRequestHeaders.Add("Cookie", cookie);
        var response = await replay.GetAsync("/");
        Assert.Equal(HttpStatusCode.Redirect, response.StatusCode);
        Assert.StartsWith("/Account/SignIn", response.Location());
    }

    [SqlFact]
    public async Task Changing_the_security_stamp_signs_out_every_device()
    {
        string email = await SoloOwnerAsync();
        var client = Client();
        await SignIn(client, email, SqlDatabaseFixture.Password);
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/")).StatusCode);

        await db.ExecuteAsync("UPDATE tbl_Users SET SecurityStamp = NEWID() WHERE Email = @email", new { email });

        var response = await client.GetAsync("/");
        Assert.StartsWith("/Account/SignIn", response.Location());
    }

    [SqlFact]
    public async Task Idle_session_locks_and_the_password_unlocks_it()
    {
        string email = await SoloOwnerAsync();
        var client = Client();
        await SignIn(client, email, SqlDatabaseFixture.Password);

        await db.ExecuteAsync("""
            UPDATE s SET LastActivityAtUtc = DATEADD(MINUTE, -30, SYSUTCDATETIME())
            FROM tbl_UserSessions s JOIN tbl_Users u ON u.UserId = s.UserId
            WHERE u.Email = @email AND s.EndedAtUtc IS NULL
            """, new { email });

        var page = await client.GetAsync("/Plan");
        Assert.StartsWith("/Account/Unlock", page.Location());
        Assert.Equal((HttpStatusCode)423, (await client.GetAsync("/api/core/gstin/27AAPFU0939F1ZV")).StatusCode);

        string token = await Token(client, "/Account/Unlock?ReturnUrl=%2FPlan");
        var wrong = await client.PostAsync("/Account/Unlock?ReturnUrl=%2FPlan", Form(token, new() { ["Password"] = "nope" }));
        Assert.Contains("That password isn&#x27;t right.", await wrong.Content.ReadAsStringAsync());

        var unlocked = await client.PostAsync("/Account/Unlock?ReturnUrl=%2FPlan", Form(token, new() { ["Password"] = SqlDatabaseFixture.Password }));
        Assert.Equal("/Plan", unlocked.Location());
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/Plan")).StatusCode);
    }

    [SqlFact]
    public async Task Opening_the_lock_screen_locks_the_session_on_the_server()
    {
        string email = await SoloOwnerAsync();
        var client = Client();
        await SignIn(client, email, SqlDatabaseFixture.Password);

        // What the page's idle timer and Ctrl+Shift+L do.
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/Account/Unlock?ReturnUrl=%2FPlan")).StatusCode);

        // Walking away from the lock screen without the password gets nowhere.
        Assert.StartsWith("/Account/Unlock", (await client.GetAsync("/Plan")).Location());

        string token = await Token(client, "/Account/Unlock");
        var unlocked = await client.PostAsync("/Account/Unlock?ReturnUrl=%2FPlan", Form(token, new() { ["Password"] = SqlDatabaseFixture.Password }));
        Assert.Equal("/Plan", unlocked.Location());
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/Plan")).StatusCode);
    }

    [SqlFact]
    public async Task A_weaker_stored_hash_is_upgraded_silently_at_sign_in()
    {
        byte[] salt = RandomNumberGenerator.GetBytes(16);
        byte[] derived = Rfc2898DeriveBytes.Pbkdf2(SqlDatabaseFixture.Password, salt, 1000, HashAlgorithmName.SHA256, 32);
        string weak = $"PBKDF2$SHA256$1000${Convert.ToBase64String(salt)}${Convert.ToBase64String(derived)}";
        string email = UniqueEmail();
        await db.ProvisionAsync("W" + Guid.NewGuid().ToString("N")[..10], "Weak Hash Co", email, passwordHash: weak);

        await SignIn(Client(), email, SqlDatabaseFixture.Password);

        string stored = await db.ScalarAsync<string>("SELECT PasswordHash FROM tbl_Users WHERE Email = @email", new { email });
        Assert.StartsWith($"PBKDF2$SHA256${PasswordHasher.CurrentIterations}$", stored);
        Assert.True(PasswordHasher.Verify(SqlDatabaseFixture.Password, stored));
    }

    [SqlFact]
    public async Task Owner_gets_the_owner_permissions_from_the_database()
    {
        string email = await SoloOwnerAsync();
        var client = Client();
        await SignIn(client, email, SqlDatabaseFixture.Password);

        long userId = await db.ScalarAsync<long>("SELECT UserId FROM tbl_Users WHERE Email = @email", new { email });
        long tenantId = await db.ScalarAsync<long>("SELECT TenantId FROM tbl_TenantUsers WHERE UserId = @userId", new { userId });
        int expected = await db.ScalarAsync<int>("""
            SELECT COUNT(DISTINCT p.PermissionCode) FROM tbl_TenantUsers tu
            JOIN tbl_TenantUserRoles tur ON tur.TenantUserId = tu.TenantUserId
            JOIN tbl_RolePermissions rp ON rp.RoleId = tur.RoleId
            JOIN tbl_Permissions p ON p.PermissionId = rp.PermissionId AND p.IsPlatformOnly = 0
            WHERE tu.UserId = @userId AND tu.TenantId = @tenantId
            """, new { userId, tenantId });

        Assert.True(expected > 50, $"Owner role should carry most permissions, got {expected}");
    }

    [SqlFact]
    public async Task Plans_trials_and_add_ons_decide_the_modules()
    {
        var store = new SqlEntitlementStore(new SqlDb(new DbOptions { ConnectionString = db.ConnectionString }));
        var now = DateTimeOffset.UtcNow;

        var (active, _) = await db.ProvisionAsync("P" + Guid.NewGuid().ToString("N")[..10], "Active Co", UniqueEmail(), status: 2);
        var start = await store.GetAsync(active);
        Assert.Equal("start", start.PlanCode);
        Assert.Equal(new HashSet<string> { ModuleKeys.Core, ModuleKeys.Billing }, start.EnabledModules(now).ToHashSet());
        Assert.Equal(1, start.Limit(Meters.Users));

        await db.ExecuteAsync("INSERT INTO tbl_TenantModules (TenantId, ModuleKey, Source) VALUES (@active, 'inventory', 2)", new { active });
        Assert.Contains(ModuleKeys.Inventory, (await store.GetAsync(active)).EnabledModules(now));

        var (trial, _) = await db.ProvisionAsync("Q" + Guid.NewGuid().ToString("N")[..10], "Trial Co", UniqueEmail(), status: 1);
        var trialing = await store.GetAsync(trial);
        Assert.Equal("trial", trialing.PlanCode);
        Assert.Contains(ModuleKeys.Accounting, trialing.EnabledModules(now));
        Assert.All(trialing.Grants, g => Assert.Equal(EntitlementSource.Trial, g.Source));

        await db.ExecuteAsync("UPDATE tbl_Tenants SET TrialEndsOnUtc = DATEADD(DAY, -1, SYSUTCDATETIME()) WHERE TenantId = @trial", new { trial });
        Assert.Equal("start", (await store.GetAsync(trial)).PlanCode);
    }

    private static string AuthCookie(HttpResponseMessage response) =>
        response.Headers.GetValues("Set-Cookie").First(c => c.StartsWith("bme.auth=")).Split(';')[0];
}
