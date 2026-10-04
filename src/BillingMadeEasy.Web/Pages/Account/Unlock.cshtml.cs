using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using BillingMadeEasy.Core.Tenancy;
using BillingMadeEasy.Web.Infrastructure.Auth;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.AspNetCore.RateLimiting;

namespace BillingMadeEasy.Web.Pages.Account;

[EnableRateLimiting("sign-in")]
public sealed class UnlockModel(IAuthService auth) : PageModel
{
    [BindProperty, Required(ErrorMessage = "Enter your password."), DataType(DataType.Password)]
    public string Password { get; set; } = "";

    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    public string? Error { get; private set; }

    public string Name => User.FindFirstValue(ClaimTypes.Name) ?? "";

    public void OnGet() { }

    public async Task<IActionResult> OnPostAsync(CancellationToken ct)
    {
        if (!ModelState.IsValid) return Page();
        string? sessionKey = User.FindFirst(AppClaims.SessionKey)?.Value;
        if (sessionKey is null || User.GetUserId() is not long userId) return RedirectToPage("/Account/SignIn");

        var outcome = await auth.UnlockAsync(sessionKey, userId, Password, RequestInfo.From(HttpContext), ct);
        switch (outcome.Status)
        {
            case SignInStatus.Success:
                return LocalRedirect(Url.IsLocalUrl(ReturnUrl) ? ReturnUrl! : "/");
            case SignInStatus.Locked:
                Error = "Too many attempts. Sign out and sign in again later.";
                return Page();
            default:
                Error = "That password isn't right.";
                return Page();
        }
    }
}
