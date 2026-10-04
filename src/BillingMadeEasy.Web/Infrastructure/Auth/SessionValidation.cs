using BillingMadeEasy.Core.Tenancy;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;

namespace BillingMadeEasy.Web.Infrastructure.Auth;

/// <summary>
/// Every authenticated request re-checks the server session. A password change, an admin lock or
/// a sign-out elsewhere ends it on the next request; idling past the tenant's limit locks it until
/// the password is entered again.
/// </summary>
public static class SessionValidation
{
    private const string LockedKey = "bme:locked";
    private const string IdleMinutesKey = "bme:idle";

    /// <summary>Minutes of inactivity before the session locks, for the page's own idle timer. 0 = never.</summary>
    public static int IdleLockMinutes(HttpContext http) => http.Items.TryGetValue(IdleMinutesKey, out var v) && v is int m ? m : 0;

    public static async Task ValidateAsync(CookieValidatePrincipalContext context)
    {
        var principal = context.Principal;
        string? sessionKey = principal?.FindFirst(AppClaims.SessionKey)?.Value;
        if (principal is null || sessionKey is null)
        {
            await RejectAsync(context);
            return;
        }

        var auth = context.HttpContext.RequestServices.GetRequiredService<IAuthService>();
        var state = await auth.ValidateSessionAsync(sessionKey, context.HttpContext.Connection.RemoteIpAddress?.ToString(), context.HttpContext.RequestAborted);

        // The session's tenant is authoritative; a cookie that disagrees is stale.
        bool tenantMismatch = principal.GetTenantId() is long claimed && state.TenantId is long current && claimed != current;
        if (state.Status == SessionStatus.Invalid || tenantMismatch)
        {
            await RejectAsync(context);
            return;
        }

        if (state.Status == SessionStatus.Locked) context.HttpContext.Items[LockedKey] = true;
        context.HttpContext.Items[IdleMinutesKey] = state.IdleLockMinutes;
    }

    /// <summary>Sends a locked session to the unlock screen; APIs get 423 so the page can prompt in place.</summary>
    public static IApplicationBuilder UseSessionLock(this IApplicationBuilder app) =>
        app.Use(async (context, next) =>
        {
            bool locked = context.Items.ContainsKey(LockedKey);
            var path = context.Request.Path;
            bool exempt = path.StartsWithSegments("/Account/Unlock") || path.StartsWithSegments("/Account/SignOut")
                          || path.StartsWithSegments("/health");

            // A flagged account replaces its password before doing anything else.
            if (!locked && !exempt && !path.StartsWithSegments("/Account/Password")
                && context.User.HasClaim(AppClaims.MustChangePassword, "1"))
            {
                if (path.StartsWithSegments("/api")) context.Response.StatusCode = StatusCodes.Status403Forbidden;
                else context.Response.Redirect("/Account/Password?required=1");
                return;
            }

            if (!locked || exempt)
            {
                await next();
                return;
            }

            if (path.StartsWithSegments("/api"))
            {
                await Results.Problem(detail: "Session locked after inactivity. Enter your password to continue.",
                    statusCode: StatusCodes.Status423Locked,
                    extensions: new Dictionary<string, object?> { ["action"] = "/Account/Unlock" }).ExecuteAsync(context);
                return;
            }

            string returnUrl = path + context.Request.QueryString;
            context.Response.Redirect("/Account/Unlock?ReturnUrl=" + Uri.EscapeDataString(returnUrl));
        });

    private static async Task RejectAsync(CookieValidatePrincipalContext context)
    {
        context.RejectPrincipal();
        await context.HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
    }
}
