using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BillingMadeEasy.Web.Pages.Account;

/// <summary>POST only, so a link or an image tag on another site can't sign someone out.</summary>
public sealed class SignOutModel : PageModel
{
    public IActionResult OnGet() => RedirectToPage("/Index");

    public async Task<IActionResult> OnPostAsync()
    {
        await HttpContext.SignOutAsync();
        return RedirectToPage("/Account/SignIn");
    }
}
