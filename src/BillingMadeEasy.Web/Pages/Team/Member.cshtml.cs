using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using BillingMadeEasy.Core.Tenancy;
using BillingMadeEasy.Web.Features.Team;
using BillingMadeEasy.Web.Infrastructure.Formatting;
using BillingMadeEasy.Web.Infrastructure.Pages;
using Microsoft.AspNetCore.Mvc;

namespace BillingMadeEasy.Web.Pages.Team;

public sealed class MemberModel(TeamStore team, InviteSender invites) : TenantPageModel
{
    public sealed class MemberForm
    {
        [Required(ErrorMessage = "Enter their name."), StringLength(120)]
        public string FullName { get; set; } = "";

        [StringLength(20)]
        public string? Mobile { get; set; }

        [StringLength(80)]
        public string? Designation { get; set; }

        [StringLength(30)]
        public string? EmployeeCode { get; set; }

        public List<long> RoleIds { get; set; } = [];
    }

    [BindProperty(SupportsGet = true)]
    public long Id { get; set; }

    [BindProperty]
    public MemberForm Form { get; set; } = new();

    public MemberDetail Detail { get; private set; } = null!;

    public IReadOnlyList<RoleRow> Roles { get; private set; } = [];

    public bool ActorIsOwner { get; private set; }

    public InviteFlash.Outcome? Invite { get; private set; }

    public bool IsSelf => Detail.Member.UserId == UserId;

    public bool CanManage => Can("Admin.User.Manage");

    /// <summary>Only an owner may change an owner: the database refuses anything else, so the page doesn't offer it.</summary>
    public bool CanEditThis => CanManage && (!Detail.Member.IsTenantOwner || ActorIsOwner);

    public bool CanDisable => Can("Admin.User.Disable");

    public async Task<IActionResult> OnGetAsync(CancellationToken ct)
    {
        Invite = InviteFlash.Take(TempData);
        if (!await LoadAsync(ct)) return NotFound();
        Form = new MemberForm
        {
            FullName = Detail.Member.FullName,
            Mobile = Detail.Member.Mobile,
            Designation = Detail.Member.Designation,
            EmployeeCode = Detail.Member.EmployeeCode,
            RoleIds = Detail.Roles.Select(r => r.RoleId).ToList(),
        };
        return Page();
    }

    public async Task<IActionResult> OnPostSaveAsync(CancellationToken ct)
    {
        if (!CanManage) return Forbid();
        if (!await LoadAsync(ct)) return NotFound();
        if (!CanEditThis) return Forbid();
        Form.Mobile = Phone.NormalizeIndianMobile(Form.Mobile);
        if (Form.Mobile is not null && !Phone.IsIndianMobile(Form.Mobile))
            ModelState.AddModelError("Form.Mobile", "A 10-digit Indian mobile number.");
        if (Form.RoleIds.Count == 0) ModelState.AddModelError("Form.RoleIds", "Choose at least one role.");
        if (!ModelState.IsValid) return await LoadAsync(ct) ? Page() : NotFound();

        var result = await team.UpdateAsync(TenantId, Id, Form.FullName.Trim(), Blank(Form.Mobile), Blank(Form.Designation), Blank(Form.EmployeeCode),
            Form.RoleIds.Distinct(), UserId, IpAddress, ct);
        if (!result.Succeeded)
        {
            ModelState.AddModelError("Form.RoleIds", result.ResultMessage ?? "That couldn't be saved.");
            return await LoadAsync(ct) ? Page() : NotFound();
        }

        Flash = "Saved. New permissions apply the next time they sign in or switch business.";
        return RedirectToPage(new { id = Id });
    }

    public async Task<IActionResult> OnPostStatusAsync(byte status, CancellationToken ct)
    {
        if (!CanDisable) return Forbid();
        if (status is not (MemberStatus.Active or MemberStatus.Suspended or MemberStatus.Removed)) return BadRequest();

        var result = await team.SetStatusAsync(TenantId, Id, status, UserId, IpAddress, ct);
        Flash = !result.Succeeded ? result.ResultMessage + "."
            : status switch
            {
                MemberStatus.Suspended => "Suspended. They were signed out and can't get in until restored.",
                MemberStatus.Removed => "Removed from the team. Their name stays on everything they did.",
                _ => "Restored. They can sign in again.",
            };
        return RedirectToPage(new { id = Id });
    }

    public async Task<IActionResult> OnPostOwnerAsync(bool isOwner, CancellationToken ct)
    {
        var result = await team.SetOwnerAsync(TenantId, Id, isOwner, UserId, IpAddress, ct);
        Flash = !result.Succeeded ? result.ResultMessage + "." : isOwner ? "They're now an owner." : "They're no longer an owner.";
        return RedirectToPage(new { id = Id });
    }

    public async Task<IActionResult> OnPostResendAsync(CancellationToken ct)
    {
        if (!CanManage) return Forbid();
        if (!await LoadAsync(ct)) return NotFound();
        if (Detail.Member.HasPassword) return RedirectToPage(new { id = Id });

        var m = Detail.Member;
        var delivery = await invites.SendAsync(Request, m.PublicId, m.UserId, m.FullName, m.Email, TenantId,
            User.FindFirstValue(AppClaims.TenantName) ?? "the business", User.FindFirstValue(ClaimTypes.Name) ?? "Your colleague", IpAddress, ct);
        InviteFlash.Store(TempData, m.FullName, m.Email, delivery);
        return RedirectToPage(new { id = Id });
    }

    private async Task<bool> LoadAsync(CancellationToken ct)
    {
        var detail = await team.GetAsync(TenantId, Id, ct);
        if (detail is null) return false;
        Detail = detail;
        Roles = await team.RolesAsync(TenantId, ct);
        ActorIsOwner = await team.IsOwnerAsync(TenantId, UserId, ct);
        return true;
    }

    private static string? Blank(string? s) => string.IsNullOrWhiteSpace(s) ? null : s.Trim();
}
