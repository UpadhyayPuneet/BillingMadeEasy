using System.ComponentModel.DataAnnotations;
using BillingMadeEasy.Web.Features.Account;
using BillingMadeEasy.Web.Infrastructure.Auth;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.AspNetCore.RateLimiting;

namespace BillingMadeEasy.Web.Pages.Account;

[EnableRateLimiting("sign-in")]
public sealed class ForgotModel(PasswordService passwords) : PageModel
{
    [BindProperty(SupportsGet = true), Required(ErrorMessage = "Enter the email or mobile you sign in with.")]
    public string Email { get; set; } = "";

    public bool Sent { get; private set; }

    public void OnGet() { }

    public async Task<IActionResult> OnPostAsync(CancellationToken ct)
    {
        if (!ModelState.IsValid) return Page();
        await passwords.RequestResetAsync(Email, Request, RequestInfo.From(HttpContext), ct);
        // Same answer whether or not an account matched, so this form can't be used to find accounts.
        Sent = true;
        return Page();
    }
}
