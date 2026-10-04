using System.ComponentModel.DataAnnotations;
using BillingMadeEasy.Core.Security;
using BillingMadeEasy.Web.Features.Team;
using BillingMadeEasy.Web.Infrastructure.Auth;
using BillingMadeEasy.Web.Infrastructure.Settings;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.AspNetCore.RateLimiting;

namespace BillingMadeEasy.Web.Pages.Account;

/// <summary>The invited person's first visit: who invited them, then a password.</summary>
[EnableRateLimiting("sign-in")]
public sealed class WelcomeModel(AccountTokens tokens, TeamStore team, SettingsReader settings) : PageModel
{
    [BindProperty(SupportsGet = true, Name = "u")]
    public string? PublicId { get; set; }

    [BindProperty(SupportsGet = true, Name = "t")]
    public string? Token { get; set; }

    [BindProperty, DataType(DataType.Password)]
    public string Password { get; set; } = "";

    [BindProperty, DataType(DataType.Password)]
    public string Confirm { get; set; } = "";

    public string? FullName { get; private set; }
    public string? Email { get; private set; }
    public InviteContext? Context { get; private set; }
    public int MinLength { get; private set; } = 10;

    /// <summary>Set when the link can't be used; the page explains instead of showing a form.</summary>
    public string? Problem { get; private set; }

    public async Task<IActionResult> OnGetAsync(CancellationToken ct)
    {
        await LoadAsync(ct);
        return Page();
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken ct)
    {
        var user = await LoadAsync(ct);
        if (user is null || Problem is not null) return Page();

        if (Password.Length < MinLength)
            ModelState.AddModelError(nameof(Password), $"Use at least {MinLength} characters. A short sentence works well.");
        else if (Password != Confirm)
            ModelState.AddModelError(nameof(Confirm), "The two passwords don't match.");
        else if (ContainsIdentity(Password, user.Email, user.FullName))
            ModelState.AddModelError(nameof(Password), "Don't use your name or email in your password.");
        if (!ModelState.IsValid) return Page();

        // Spends the token: it can't be used again, whatever happens next.
        if (!await tokens.ConsumeAsync(user.UserId, TokenType.Invite, Token!, ct))
        {
            Problem = "This invitation link has expired or was already used.";
            return Page();
        }

        var set = await team.SetPasswordAsync(user.UserId, PasswordHasher.Hash(Password), Context?.TenantId, HttpContext.Connection.RemoteIpAddress?.ToString(), ct);
        if (!set.Succeeded)
        {
            Problem = "Your password couldn't be saved. Ask for a new invitation.";
            return Page();
        }

        return RedirectToPage("/Account/SignIn", new { email = user.Email, welcome = 1 });
    }

    private async Task<AccountTokens.UserRow?> LoadAsync(CancellationToken ct)
    {
        if (!Guid.TryParse(PublicId, out var publicId) || string.IsNullOrWhiteSpace(Token))
        {
            Problem = "This link is incomplete. Open it straight from the email, or ask for a new invitation.";
            return null;
        }

        var user = await tokens.UserByPublicIdAsync(publicId, ct);
        if (user is null || !user.Succeeded || user.UserId == 0)
        {
            Problem = "This invitation isn't valid. Ask for a new one.";
            return null;
        }

        FullName = user.FullName;
        Email = user.Email;
        Context = await team.InviteContextAsync(user.UserId, ct);
        MinLength = await settings.GetIntAsync(Context?.TenantId, "Security.PasswordMinLength", 10);

        if (!await tokens.IsLiveAsync(user.UserId, TokenType.Invite, ct))
            Problem = user.Status == 2
                ? "You've already set your password, so this link is spent. Sign in instead."
                : "This invitation has expired or was replaced by a newer one.";

        return user;
    }

    private static bool ContainsIdentity(string password, string email, string fullName)
    {
        string p = password.ToLowerInvariant();
        string local = email.Split('@')[0].ToLowerInvariant();
        return (local.Length >= 4 && p.Contains(local))
               || fullName.Split(' ', StringSplitOptions.RemoveEmptyEntries).Any(n => n.Length >= 4 && p.Contains(n.ToLowerInvariant()));
    }
}
