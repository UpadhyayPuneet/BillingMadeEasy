using BillingMadeEasy.Core.Tenancy;
using BillingMadeEasy.Web.Infrastructure.Auth;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BillingMadeEasy.Web.Pages.Account;

/// <summary>POST only, so a link or an image tag on another site can't sign someone out.</summary>
public sealed class SignOutModel(IAuthService auth) : PageModel
{
    public IActionResult OnGet() => RedirectToPage("/Index");

    public async Task<IActionResult> OnPostAsync(CancellationToken ct)
    {
        // End the server session first: the cookie alone is not proof of being signed in.
        if (User.FindFirst(AppClaims.SessionKey)?.Value is { } sessionKey)
            await auth.SignOutAsync(sessionKey, ct);
        await HttpContext.SignOutAsync();
        return RedirectToPage("/Account/SignIn");
    }
}
