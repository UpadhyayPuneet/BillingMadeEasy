using System.Security.Claims;
using BillingMadeEasy.Core.Tenancy;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;

namespace BillingMadeEasy.Web.Infrastructure.Auth;

/// <summary>Issues the auth cookie in two steps: the person (no tenant yet), then the person inside a business.</summary>
public static class SessionSignIn
{
    public static Task SignInPersonAsync(HttpContext http, SignInOutcome outcome, bool remember) =>
        IssueAsync(http, Person(outcome.UserId, outcome.DisplayName, outcome.IsPlatformAdmin, outcome.SessionKey), remember);

    /// <summary>After choosing a business from the picker: the person is already signed in.</summary>
    public static Task SignInTenantAsync(HttpContext http, ClaimsPrincipal current, TenantSession session, bool remember) =>
        SignInTenantAsync(http,
            current.GetUserId() ?? throw new InvalidOperationException("No signed-in person."),
            current.Identity?.Name ?? string.Empty,
            current.HasClaim(AppClaims.PlatformAdmin, "1"),
            current.FindFirst(AppClaims.SessionKey)?.Value ?? throw new InvalidOperationException("No session."),
            session, remember);

    /// <summary>Straight from sign-in when the person belongs to exactly one business.</summary>
    public static Task SignInTenantAsync(HttpContext http, SignInOutcome outcome, TenantSession session, bool remember) =>
        SignInTenantAsync(http, outcome.UserId, outcome.DisplayName, outcome.IsPlatformAdmin, outcome.SessionKey, session, remember);

    private static Task SignInTenantAsync(HttpContext http, long userId, string displayName, bool platformAdmin, string sessionKey, TenantSession session, bool remember)
    {
        var claims = Person(userId, displayName, platformAdmin, sessionKey);
        claims.Add(new Claim(AppClaims.TenantId, session.TenantId.ToString()));
        claims.Add(new Claim(AppClaims.TenantName, session.TenantName));
        claims.Add(new Claim(ClaimTypes.Role, session.RoleName));
        claims.AddRange(session.Permissions.Select(p => new Claim(AppClaims.Permission, p)));
        return IssueAsync(http, claims, remember);
    }

    private static List<Claim> Person(long userId, string displayName, bool platformAdmin, string sessionKey)
    {
        var claims = new List<Claim>
        {
            new(AppClaims.UserId, userId.ToString()),
            new(ClaimTypes.Name, displayName),
            new(AppClaims.SessionKey, sessionKey),
        };
        if (platformAdmin) claims.Add(new Claim(AppClaims.PlatformAdmin, "1"));
        return claims;
    }

    private static Task IssueAsync(HttpContext http, List<Claim> claims, bool remember)
    {
        var identity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme, ClaimTypes.Name, ClaimTypes.Role);
        var properties = new AuthenticationProperties { IsPersistent = remember, AllowRefresh = true };
        return http.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, new ClaimsPrincipal(identity), properties);
    }
}
