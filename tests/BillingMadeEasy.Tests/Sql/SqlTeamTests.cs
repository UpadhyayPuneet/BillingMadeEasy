using System.Net;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Mvc.Testing;
using static BillingMadeEasy.Tests.Sql.WebFlow;

namespace BillingMadeEasy.Tests.Sql;

/// <summary>Invitations, the welcome page, roles and access changes, end to end.</summary>
public partial class SqlTeamTests(SqlDatabaseFixture db) : IClassFixture<SqlDatabaseFixture>
{
    [GeneratedRegex("value=\"(http://localhost/Account/Welcome\\?u=[0-9a-f]+&amp;t=[A-Za-z0-9_\\-%]+)\"")]
    private static partial Regex InviteLink();

    private HttpClient Client() =>
        new SqlAppFactory(db).CreateClient(new WebApplicationFactoryClientOptions { AllowAutoRedirect = false });

    private static string Unique(string prefix) => prefix + Guid.NewGuid().ToString("N")[..10];

    private async Task<(HttpClient Client, long TenantId)> OwnerAsync()
    {
        string email = Unique("o") + "@test.in";
        var (tenantId, _) = await db.ProvisionAsync(Unique("T"), "Team " + Unique(""), email);
        var client = Client();
        await SignIn(client, email, SqlDatabaseFixture.Password);
        return (client, tenantId);
    }

    private async Task<long> RoleIdAsync(long tenantId, string code) =>
        await db.ScalarAsync<long>("SELECT RoleId FROM tbl_Roles WHERE TenantId = @tenantId AND RoleCode = @code", new { tenantId, code });

    private static Task<HttpResponseMessage> Invite(HttpClient client, string name, string email, params long[] roleIds)
    {
        var fields = new List<KeyValuePair<string, string>>
        {
            new("Form.FullName", name), new("Form.Email", email), new("Form.Mobile", "+91 98765-43210"),
        };
        fields.AddRange(roleIds.Select(r => new KeyValuePair<string, string>("Form.RoleIds", r.ToString())));
        return PostMany(client, "/Team/Invite", "/Team/Invite", fields);
    }

    private static async Task<HttpResponseMessage> PostMany(HttpClient client, string page, string action, List<KeyValuePair<string, string>> fields)
    {
        fields.Add(new("__RequestVerificationToken", await Token(client, page)));
        return await client.PostAsync(action, new FormUrlEncodedContent(fields));
    }

    [SqlFact]
    public async Task Invite_set_password_sign_in_and_the_link_dies()
    {
        var (owner, tenantId) = await OwnerAsync();
        string email = Unique("n") + "@test.in";

        var invited = await Invite(owner, "Neha Sharma", email, await RoleIdAsync(tenantId, "ACCOUNTANT"));
        Assert.StartsWith("/Team/Member/", invited.Location());
        Assert.Equal("9876543210", await db.ScalarAsync<string>("SELECT Mobile FROM tbl_Users WHERE Email = @email", new { email }));

        // Email is off in tests, so the page offers the link to share, once.
        string member = await owner.GetStringAsync(invited.Location());
        string link = WebUtility.HtmlDecode(InviteLink().Match(member).Groups[1].Value);
        Assert.False(string.IsNullOrEmpty(link), "Share link not shown");
        Assert.DoesNotMatch(InviteLink(), await owner.GetStringAsync(invited.Location()));

        var person = Client();
        string path = new Uri(link).PathAndQuery;
        string welcome = await person.GetStringAsync(path);
        Assert.Contains("added you to", welcome);
        Assert.Contains("as Accountant", welcome);

        var tooShort = await Post(person, path, path, new() { ["Password"] = "short", ["Confirm"] = "short" });
        Assert.Contains("Use at least 10 characters", await tooShort.Content.ReadAsStringAsync());

        var set = await Post(person, path, path, new() { ["Password"] = "Ledger and tea at nine", ["Confirm"] = "Ledger and tea at nine" });
        Assert.StartsWith("/Account/SignIn", set.Location());

        var signedIn = await SignIn(person, email, "Ledger and tea at nine");
        Assert.Equal("/", signedIn.Location());
        Assert.Equal(HttpStatusCode.OK, (await person.GetAsync("/")).StatusCode);

        Assert.Contains("this link is spent", await Client().GetStringAsync(path));
    }

    [SqlFact]
    public async Task Only_an_owner_can_hand_out_the_owner_role()
    {
        var (owner, tenantId) = await OwnerAsync();
        string adminEmail = Unique("a") + "@test.in";
        var (_, adminUserId) = await db.ProvisionAsync(Unique("X"), "Admin's own", adminEmail);
        await db.AddMemberAsync(tenantId, adminUserId, "ADMIN");

        var admin = Client();
        await SignIn(admin, adminEmail, SqlDatabaseFixture.Password);
        await Choose(admin, tenantId);

        var attempt = await Invite(admin, "Sneaky Owner", Unique("s") + "@test.in", await RoleIdAsync(tenantId, "OWNER"));
        Assert.Equal(HttpStatusCode.OK, attempt.StatusCode);
        Assert.Contains("Only an owner can give someone the Owner role", await attempt.Content.ReadAsStringAsync());
        Assert.Equal(1, await db.ScalarAsync<int>("SELECT COUNT(*) FROM tbl_AuditLog WHERE TenantId = @tenantId AND ActionCode = 'User.OwnerEscalationBlocked'", new { tenantId }));
    }

    [SqlFact]
    public async Task Suspending_someone_signs_them_out_at_once()
    {
        var (owner, tenantId) = await OwnerAsync();
        string email = Unique("m") + "@test.in";
        var (_, userId) = await db.ProvisionAsync(Unique("Y"), "Member's own", email);
        await db.AddMemberAsync(tenantId, userId, "STAFF");
        long tenantUserId = await db.ScalarAsync<long>("SELECT TenantUserId FROM tbl_TenantUsers WHERE TenantId = @tenantId AND UserId = @userId", new { tenantId, userId });

        var member = Client();
        await SignIn(member, email, SqlDatabaseFixture.Password);
        await Choose(member, tenantId);
        Assert.Equal(HttpStatusCode.OK, (await member.GetAsync("/")).StatusCode);

        var suspended = await Post(owner, $"/Team/Member/{tenantUserId}", $"/Team/Member/{tenantUserId}?handler=Status", new() { ["status"] = "3" });
        Assert.Equal($"/Team/Member/{tenantUserId}", suspended.Location());
        Assert.Contains("Suspended. They were signed out", await owner.GetStringAsync(suspended.Location()));

        // Their session in this business is over on the very next request.
        Assert.StartsWith("/Account/SignIn", (await member.GetAsync("/")).Location());
    }

    [SqlFact]
    public async Task You_cannot_lock_yourself_out()
    {
        var (owner, tenantId) = await OwnerAsync();
        long self = await db.ScalarAsync<long>("SELECT TenantUserId FROM tbl_TenantUsers WHERE TenantId = @tenantId AND IsTenantOwner = 1", new { tenantId });

        var removed = await Post(owner, $"/Team/Member/{self}", $"/Team/Member/{self}?handler=Status", new() { ["status"] = "4" });
        Assert.Contains("You can&#x27;t suspend or remove your own account", await owner.GetStringAsync(removed.Location()));
        Assert.Equal(HttpStatusCode.OK, (await owner.GetAsync("/Team")).StatusCode);
    }

    [SqlFact]
    public async Task A_new_role_grants_exactly_what_was_ticked()
    {
        var (owner, tenantId) = await OwnerAsync();
        int view = await db.ScalarAsync<int>("SELECT PermissionId FROM tbl_Permissions WHERE PermissionCode = 'Party.Customer.View'");

        var created = await PostMany(owner, "/Team/Role", "/Team/Role", [new("Form.RoleName", "Front desk"), new("Form.PermissionIds", view.ToString())]);
        Assert.Equal("/Team/Roles", created.Location());

        long roleId = await db.ScalarAsync<long>("SELECT RoleId FROM tbl_Roles WHERE TenantId = @tenantId AND RoleName = 'Front desk'", new { tenantId });
        Assert.Equal(["Party.Customer.View"], (await db.ScalarAsync<string>(
            "SELECT STRING_AGG(p.PermissionCode, ',') FROM tbl_RolePermissions rp JOIN tbl_Permissions p ON p.PermissionId = rp.PermissionId WHERE rp.RoleId = @roleId", new { roleId })).Split(','));

        string email = Unique("f") + "@test.in";
        var (_, userId) = await db.ProvisionAsync(Unique("Z"), "Desk's own", email);
        await db.ExecuteAsync("""
            INSERT INTO tbl_TenantUsers (TenantId, UserId, IsTenantOwner, IsDefaultTenant, Status, AcceptedAtUtc, IsActive) VALUES (@tenantId, @userId, 0, 0, 2, SYSUTCDATETIME(), 1);
            INSERT INTO tbl_TenantUserRoles (TenantUserId, RoleId, AssignedAtUtc) VALUES (SCOPE_IDENTITY(), @roleId, SYSUTCDATETIME());
            """, new { tenantId, userId, roleId });

        var desk = Client();
        await SignIn(desk, email, SqlDatabaseFixture.Password);
        await Choose(desk, tenantId);
        Assert.Equal(HttpStatusCode.OK, (await desk.GetAsync("/Parties?role=customer")).StatusCode);
        Assert.StartsWith("/Account/Denied", (await desk.GetAsync("/Parties/Edit?role=customer")).Location());
        Assert.StartsWith("/Account/Denied", (await desk.GetAsync("/Team")).Location());
    }
}
