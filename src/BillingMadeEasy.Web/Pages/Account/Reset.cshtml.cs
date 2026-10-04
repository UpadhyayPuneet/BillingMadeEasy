using System.ComponentModel.DataAnnotations;
using BillingMadeEasy.Web.Features.Account;
using BillingMadeEasy.Web.Infrastructure.Auth;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.AspNetCore.RateLimiting;

namespace BillingMadeEasy.Web.Pages.Account;

/// <summary>Choose a new password from an emailed link. Every device is signed out afterwards.</summary>
[EnableRateLimiting("sign-in")]
public sealed class ResetModel(AccountTokens tokens, PasswordService passwords) : PageModel
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
    public int MinLength { get; private set; } = 10;
    public string? Problem { get; private set; }

    public async Task OnGetAsync(CancellationToken ct) => await LoadAsync(ct);

    public async Task<IActionResult> OnPostAsync(CancellationToken ct)
    {
        var user = await LoadAsync(ct);
        if (user is null || Problem is not null) return Page();

        if (await passwords.CheckAsync(user.UserId, null, Password, Confirm, user.Email, user.FullName, ct) is { } rule)
        {
            ModelState.AddModelError(rule.Contains("match") ? nameof(Confirm) : nameof(Password), rule);
            return Page();
        }

        if (!await tokens.ConsumeAsync(user.UserId, TokenType.PasswordReset, Token!, ct))
        {
            Problem = "This link has expired or was already used. Ask for a new one.";
            return Page();
        }

        if (!await passwords.SetAsync(user.UserId, Password, PasswordChangeReason.Reset, null, HttpContext.Connection.RemoteIpAddress?.ToString(), ct))
        {
            Problem = "Your password couldn't be saved. Ask for a new link.";
            return Page();
        }

        return RedirectToPage("/Account/SignIn", new { email = user.Email, reset = 1 });
    }

    private async Task<AccountTokens.UserRow?> LoadAsync(CancellationToken ct)
    {
        if (!Guid.TryParse(PublicId, out var publicId) || string.IsNullOrWhiteSpace(Token))
        {
            Problem = "This link is incomplete. Open it straight from the email.";
            return null;
        }

        var user = await tokens.UserByPublicIdAsync(publicId, ct);
        if (user is null || !user.Succeeded || user.UserId == 0 || !user.IsActive)
        {
            Problem = "This link isn't valid. Ask for a new one.";
            return null;
        }

        FullName = user.FullName;
        Email = user.Email;
        MinLength = await passwords.MinLengthAsync(null, ct);
        if (!await tokens.IsLiveAsync(user.UserId, TokenType.PasswordReset, ct))
            Problem = "This link has expired, was already used, or a newer one was sent.";
        return user;
    }
}
