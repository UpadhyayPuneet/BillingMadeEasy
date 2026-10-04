using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using BillingMadeEasy.Core.Tenancy;
using BillingMadeEasy.Web.Features.Team;
using BillingMadeEasy.Web.Infrastructure.Email;
using BillingMadeEasy.Web.Infrastructure.Formatting;
using BillingMadeEasy.Web.Infrastructure.Pages;
using Microsoft.AspNetCore.Mvc;

namespace BillingMadeEasy.Web.Pages.Team;

public sealed class InviteModel(TeamStore team, InviteSender invites) : TenantPageModel
{
    public sealed class InviteForm
    {
        [Required(ErrorMessage = "Enter their name."), StringLength(120)]
        public string FullName { get; set; } = "";

        [Required(ErrorMessage = "Enter their email; the invitation goes there."), EmailAddress(ErrorMessage = "That email address doesn't look right."), StringLength(150)]
        public string Email { get; set; } = "";

        [StringLength(20)]
        public string? Mobile { get; set; }

        [StringLength(80)]
        public string? Designation { get; set; }

        [StringLength(30)]
        public string? EmployeeCode { get; set; }

        public List<long> RoleIds { get; set; } = [];
    }

    [BindProperty]
    public InviteForm Form { get; set; } = new();

    public IReadOnlyList<RoleRow> Roles { get; private set; } = [];

    public bool ActorIsOwner { get; private set; }

    public async Task OnGetAsync(CancellationToken ct) => await LoadAsync(ct);

    public async Task<IActionResult> OnPostAsync(CancellationToken ct)
    {
        Form.FullName = Form.FullName?.Trim() ?? "";
        Form.Email = Form.Email?.Trim() ?? "";
        Form.Mobile = Phone.NormalizeIndianMobile(Form.Mobile);
        if (Form.Mobile is not null && !Phone.IsIndianMobile(Form.Mobile))
            ModelState.AddModelError("Form.Mobile", "A 10-digit Indian mobile number.");
        if (Form.RoleIds.Count == 0) ModelState.AddModelError("Form.RoleIds", "Choose at least one role.");
        if (!ModelState.IsValid)
        {
            await LoadAsync(ct);
            return Page();
        }

        var result = await team.InviteAsync(TenantId, Form.FullName, Form.Email, Form.Mobile, Blank(Form.Designation), Blank(Form.EmployeeCode),
            Form.RoleIds.Distinct(), UserId, IpAddress, ct);
        if (!result.Succeeded)
        {
            ModelState.AddModelError(result.ResultMessage?.Contains("email", StringComparison.OrdinalIgnoreCase) == true ? "Form.Email" : "Form.RoleIds",
                result.ResultMessage ?? "That couldn't be saved.");
            await LoadAsync(ct);
            return Page();
        }

        var member = await team.GetAsync(TenantId, result.TenantUserId, ct);
        if (member is not null && member.Member.HasPassword)
        {
            Flash = $"{Form.FullName} already has an account, so they're in. They'll see {TenantName} next time they sign in.";
            return RedirectToPage("/Team/Member", new { id = result.TenantUserId });
        }

        var delivery = await invites.SendAsync(Request, result.PublicId, result.UserId, Form.FullName, Form.Email,
            TenantId, TenantName, User.FindFirstValue(ClaimTypes.Name) ?? "Your colleague", IpAddress, ct);

        InviteFlash.Store(TempData, Form.FullName, Form.Email, delivery);
        return RedirectToPage("/Team/Member", new { id = result.TenantUserId });
    }

    private string TenantName => User.FindFirstValue(AppClaims.TenantName) ?? "the business";

    private async Task LoadAsync(CancellationToken ct)
    {
        Roles = await team.RolesAsync(TenantId, ct);
        ActorIsOwner = await team.IsOwnerAsync(TenantId, UserId, ct);
    }

    private static string? Blank(string? s) => string.IsNullOrWhiteSpace(s) ? null : s.Trim();
}

/// <summary>Carries the invite outcome across the redirect, shown once on the member page.</summary>
public static class InviteFlash
{
    private const string Key = "InviteOutcome";

    public sealed record Outcome(string Name, string Email, EmailOutcome Delivery, string? Link);

    public static void Store(Microsoft.AspNetCore.Mvc.ViewFeatures.ITempDataDictionary temp, string name, string email, InviteDelivery? delivery) =>
        temp[Key] = System.Text.Json.JsonSerializer.Serialize(new Outcome(name, email, delivery?.Email ?? EmailOutcome.Failed, delivery?.Link));

    public static Outcome? Take(Microsoft.AspNetCore.Mvc.ViewFeatures.ITempDataDictionary temp) =>
        temp[Key] is string json ? System.Text.Json.JsonSerializer.Deserialize<Outcome>(json) : null;
}
