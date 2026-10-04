using System.ComponentModel.DataAnnotations;
using BillingMadeEasy.Web.Infrastructure.Auth;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.AspNetCore.RateLimiting;

namespace BillingMadeEasy.Web.Pages.Account;

[EnableRateLimiting("sign-in")]
public sealed class SignInModel(IAuthService auth, IWebHostEnvironment environment) : PageModel
{
    [BindProperty, Required(ErrorMessage = "Enter your email or mobile number.")]
    public string Identifier { get; set; } = "";

    [BindProperty, Required(ErrorMessage = "Enter your password."), DataType(DataType.Password)]
    public string Password { get; set; } = "";

    [BindProperty]
    public bool Remember { get; set; }

    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    public string? Error { get; private set; }

    public bool ShowDemoHint => environment.IsDevelopment();

    public IActionResult OnGet() =>
        User.Identity?.IsAuthenticated == true ? LocalRedirect(SafeReturnUrl) : Page();

    public async Task<IActionResult> OnPostAsync(CancellationToken ct)
    {
        if (!ModelState.IsValid) return Page();

        var outcome = await auth.SignInAsync(Identifier, Password, RequestInfo.From(HttpContext), ct);
        switch (outcome.Status)
        {
            case SignInStatus.Success:
                break;
            case SignInStatus.Locked:
                Error = outcome.LockedUntil is { } until
                    ? $"Too many attempts. Try again in {Math.Max(1, (int)Math.Ceiling((until - DateTimeOffset.UtcNow).TotalMinutes))} minutes."
                    : "Too many attempts. Sign-in is blocked until an administrator releases it.";
                return Page();
            case SignInStatus.NoActiveBusiness:
                Error = "Your account isn't part of an active business yet. Ask the owner to invite you.";
                return Page();
            default:
                // Same words for unknown identity and wrong password, so this form can't be used to find accounts.
                Error = "That email and password don't match.";
                return Page();
        }

        var tenants = outcome.Tenants ?? [];
        var session = tenants.Count == 1 ? await auth.SelectTenantAsync(outcome.SessionKey, outcome.UserId, tenants[0].TenantId, ct) : null;
        if (session is not null)
        {
            await SessionSignIn.SignInTenantAsync(HttpContext, outcome, session, Remember);
            return LocalRedirect(SafeReturnUrl);
        }

        await SessionSignIn.SignInPersonAsync(HttpContext, outcome, Remember);
        return RedirectToPage("/Account/ChooseBusiness", new { ReturnUrl = SafeReturnUrl });
    }

    private string SafeReturnUrl => Url.IsLocalUrl(ReturnUrl) ? ReturnUrl! : "/";
}
