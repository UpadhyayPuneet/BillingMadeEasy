using System.Security.Claims;
using BillingMadeEasy.Core.Tenancy;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;

namespace BillingMadeEasy.Web.Infrastructure.Auth;

/// <summary>Issues the auth cookie in two steps: the person (no tenant yet), then the person inside a business.</summary>
public static class SessionSignIn
{
    public static Task SignInPersonAsync(HttpContext http, SignInOutcome outcome, bool remember)
    {
        var claims = Person(outcome.UserId, outcome.DisplayName, outcome.IsPlatformAdmin, outcome.SessionKey, outcome.Email);
        if (outcome.MustChangePassword) claims.Add(new Claim(AppClaims.MustChangePassword, "1"));
        return IssueAsync(http, claims, remember);
    }

    /// <summary>Same person, same business, new server session (after a password change ended the old one).</summary>
    public static Task ReissueAsync(HttpContext http, ClaimsPrincipal current, string newSessionKey, bool remember)
    {
        var claims = current.Claims
            .Where(c => c.Type is not (AppClaims.SessionKey or AppClaims.MustChangePassword))
            .Select(c => new Claim(c.Type, c.Value))
            .Append(new Claim(AppClaims.SessionKey, newSessionKey))
            .ToList();
        return IssueAsync(http, claims, remember);
    }

    /// <summary>After choosing a business from the picker: the person is already signed in.</summary>
    public static Task SignInTenantAsync(HttpContext http, ClaimsPrincipal current, TenantSession session, bool remember) =>
        SignInTenantAsync(http,
            current.GetUserId() ?? throw new InvalidOperationException("No signed-in person."),
            current.Identity?.Name ?? string.Empty,
            current.HasClaim(AppClaims.PlatformAdmin, "1"),
            current.FindFirst(AppClaims.SessionKey)?.Value ?? throw new InvalidOperationException("No session."),
            current.FindFirst(ClaimTypes.Email)?.Value ?? "",
            session, remember, current.HasClaim(AppClaims.MustChangePassword, "1"));

    /// <summary>Straight from sign-in when the person belongs to exactly one business.</summary>
    public static Task SignInTenantAsync(HttpContext http, SignInOutcome outcome, TenantSession session, bool remember) =>
        SignInTenantAsync(http, outcome.UserId, outcome.DisplayName, outcome.IsPlatformAdmin, outcome.SessionKey, outcome.Email, session, remember, outcome.MustChangePassword);

    private static Task SignInTenantAsync(HttpContext http, long userId, string displayName, bool platformAdmin, string sessionKey, string email, TenantSession session, bool remember, bool mustChange)
    {
        var claims = Person(userId, displayName, platformAdmin, sessionKey, email);
        claims.Add(new Claim(AppClaims.TenantId, session.TenantId.ToString()));
        claims.Add(new Claim(AppClaims.TenantName, session.TenantName));
        claims.Add(new Claim(ClaimTypes.Role, session.RoleName));
        claims.AddRange(session.Permissions.Select(p => new Claim(AppClaims.Permission, p)));
        if (mustChange) claims.Add(new Claim(AppClaims.MustChangePassword, "1"));
        return IssueAsync(http, claims, remember);
    }

    private static List<Claim> Person(long userId, string displayName, bool platformAdmin, string sessionKey, string email)
    {
        var claims = new List<Claim>
        {
            new(AppClaims.UserId, userId.ToString()),
            new(ClaimTypes.Name, displayName),
            new(ClaimTypes.Email, email),
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
