using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using BillingMadeEasy.Core.Tenancy;
using BillingMadeEasy.Web.Features.Account;
using BillingMadeEasy.Web.Infrastructure.Auth;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.AspNetCore.RateLimiting;

namespace BillingMadeEasy.Web.Pages.Account;

/// <summary>
/// Change your own password. Other devices are signed out; this one carries on with a fresh session.
/// When the account is flagged to change its password, this is the only page available.
/// </summary>
[EnableRateLimiting("sign-in")]
public sealed class PasswordModel(PasswordService passwords, IAuthService auth) : PageModel
{
    [BindProperty, DataType(DataType.Password)]
    public string Current { get; set; } = "";

    [BindProperty, DataType(DataType.Password)]
    public string Password { get; set; } = "";

    [BindProperty, DataType(DataType.Password)]
    public string Confirm { get; set; } = "";

    public bool Required => User.HasClaim(AppClaims.MustChangePassword, "1");

    public int MinLength { get; private set; } = 10;

    public bool Done { get; private set; }

    public async Task OnGetAsync(bool done, CancellationToken ct)
    {
        Done = done;
        MinLength = await passwords.MinLengthAsync(User.GetTenantId(), ct);
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken ct)
    {
        long userId = User.GetUserId()!.Value;
        long? tenantId = User.GetTenantId();
        MinLength = await passwords.MinLengthAsync(tenantId, ct);

        // A forced change follows straight on from signing in with the old password.
        if (!Required && !await passwords.VerifyCurrentAsync(userId, Current, ct))
        {
            ModelState.AddModelError(nameof(Current), "That isn't your current password.");
            return Page();
        }

        string email = User.FindFirstValue(ClaimTypes.Email) ?? "";
        if (await passwords.CheckAsync(userId, tenantId, Password, Confirm, email, User.Identity?.Name ?? "", ct) is { } rule)
        {
            ModelState.AddModelError(rule.Contains("match") ? nameof(Confirm) : nameof(Password), rule);
            return Page();
        }

        var info = RequestInfo.From(HttpContext);
        if (!await passwords.SetAsync(userId, Password, PasswordChangeReason.SelfChange, tenantId, info.IpAddress, ct))
        {
            ModelState.AddModelError("", "Your password couldn't be saved. Try again.");
            return Page();
        }

        // Every session just ended, this one included. Carry on in a new one.
        string newKey = await auth.RenewSessionAsync(userId, tenantId, info, ct);
        var current = await HttpContext.AuthenticateAsync();
        await SessionSignIn.ReissueAsync(HttpContext, User, newKey, current.Properties?.IsPersistent ?? false);

        if (tenantId is null) return RedirectToPage("/Account/ChooseBusiness");
        return RedirectToPage(new { done = "true" });
    }
}
