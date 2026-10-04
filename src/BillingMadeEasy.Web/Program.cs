using System.Threading.RateLimiting;
using BillingMadeEasy.Core.Modules;
using BillingMadeEasy.Core.Tenancy;
using BillingMadeEasy.Data;
using BillingMadeEasy.Web.Infrastructure;
using BillingMadeEasy.Web.Infrastructure.Auth;
using BillingMadeEasy.Web.Infrastructure.Demo;
using BillingMadeEasy.Web.Infrastructure.Modules;
using BillingMadeEasy.Web.Modules;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc.RazorPages;

var builder = WebApplication.CreateBuilder(args);
var services = builder.Services;

// ── Modules: each one registers itself; removing a line removes the module ──
services.AddSingleton<IAppModule, EssentialsModule>();

// ── Data and sign-in provider ──
bool hasDatabase = services.AddBillingDatabase(builder.Configuration);
string authProvider = builder.Configuration["Auth:Provider"] ?? "Sql";

if (string.Equals(authProvider, "Demo", StringComparison.OrdinalIgnoreCase))
{
    if (!builder.Environment.IsDevelopment())
        throw new InvalidOperationException("Auth:Provider=Demo is only allowed in Development.");
    services.AddSingleton<IAuthService, DemoAuthService>();
    services.AddSingleton<IEntitlementStore, DemoEntitlementStore>();
}
else
{
    // The SQL-backed IAuthService and IEntitlementStore wrap the usp_Auth_* procedures from
    // database/scripts. They land once those scripts are in the repository (see docs/MIGRATION.md).
    throw new InvalidOperationException(hasDatabase
        ? "SQL sign-in is not wired yet. Set Auth:Provider=Demo in Development until the usp_Auth_* port lands."
        : "No connection string 'BillingMadeEasy'. Set one, or use Auth:Provider=Demo in Development.");
}

services.AddMemoryCache();
services.AddSingleton(TimeProvider.System);
services.AddSingleton<EntitlementService>();
services.AddScoped<NavigationService>();

// ── Authentication: cookie, HttpOnly, SameSite=Lax, sliding ──
services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.Cookie.Name = "bme.auth";
        options.Cookie.HttpOnly = true;
        options.Cookie.SameSite = SameSiteMode.Lax;
        options.Cookie.SecurePolicy = builder.Environment.IsDevelopment() ? CookieSecurePolicy.SameAsRequest : CookieSecurePolicy.Always;
        options.LoginPath = "/Account/SignIn";
        options.LogoutPath = "/Account/SignOut";
        options.AccessDeniedPath = "/Account/Denied";
        options.ExpireTimeSpan = TimeSpan.FromHours(8);
        options.SlidingExpiration = true;
        options.Events.OnRedirectToLogin = context =>
        {
            if (context.Request.Path.StartsWithSegments("/api")) context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            else context.Response.Redirect(context.RedirectUri);
            return Task.CompletedTask;
        };
    });

// ── Authorization: everything needs a signed-in person inside a business unless it says otherwise ──
services.AddSingleton<IAuthorizationPolicyProvider, PolicyProvider>();
services.AddSingleton<IAuthorizationHandler, TenantSelectedHandler>();
services.AddSingleton<IAuthorizationHandler, ModuleHandler>();
services.AddSingleton<IAuthorizationHandler, PermissionHandler>();
services.AddSingleton<IAuthorizationMiddlewareResultHandler, FriendlyAuthorizationResultHandler>();
services.AddAuthorizationBuilder()
    .SetFallbackPolicy(new AuthorizationPolicyBuilder().RequireAuthenticatedUser().AddRequirements(new TenantSelectedRequirement()).Build())
    .AddPolicy(Policies.SignedIn, p => p.RequireAuthenticatedUser())
    .AddPolicy(Policies.PlatformAdmin, p => p.RequireAuthenticatedUser().RequireClaim(AppClaims.PlatformAdmin, "1"));

// ── Throttle sign-in per IP (enumeration and brute force) ──
services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddPolicy("sign-in", context => RateLimitPartition.GetFixedWindowLimiter(
        context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
        _ => new FixedWindowRateLimiterOptions { PermitLimit = 10, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 }));
});

services.AddRazorPages(options =>
{
    // Per page, not the folder: [AllowAnonymous] beats any [Authorize], so a folder-wide
    // allowance would silently open the business picker to signed-out visitors.
    options.Conventions.AllowAnonymousToPage("/Account/SignIn");
    options.Conventions.AllowAnonymousToPage("/Account/SignOut");
    options.Conventions.AllowAnonymousToPage("/Account/Denied");
    options.Conventions.AuthorizePage("/Account/ChooseBusiness", Policies.SignedIn);
    options.Conventions.AllowAnonymousToPage("/Error");
});

// A module's page folder is gated by its entitlement: no per-page attribute to forget.
services.AddOptions<RazorPagesOptions>().Configure<IEnumerable<IAppModule>>((options, modules) =>
{
    foreach (var module in modules.Where(m => m.PagesFolder is not null))
        options.Conventions.AuthorizeFolder(module.PagesFolder!, Policies.Module(module.Key));
});

services.AddProblemDetails();
services.AddHealthChecks();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
    app.UseHttpsRedirection();
}

app.UseSecurityHeaders();
app.UseStaticFiles();
app.UseRouting();
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();

app.MapHealthChecks("/health").AllowAnonymous();
app.MapRazorPages();

var api = app.MapGroup("/api").RequireAuthorization();
foreach (var module in app.Services.GetServices<IAppModule>())
{
    var group = api.MapGroup(string.Empty);
    if (ModuleCatalog.Find(module.Key) is not { IsCore: true }) group.RequireAuthorization(Policies.Module(module.Key));
    module.MapEndpoints(group);
}

app.Run();

public partial class Program;
