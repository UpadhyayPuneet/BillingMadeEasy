using System.ComponentModel.DataAnnotations;
using BillingMadeEasy.Web.Features.Team;
using BillingMadeEasy.Web.Infrastructure.Pages;
using Microsoft.AspNetCore.Mvc;

namespace BillingMadeEasy.Web.Pages.Team;

public sealed class RoleModel(TeamStore team) : TenantPageModel
{
    public sealed class RoleForm
    {
        [Required(ErrorMessage = "Give the role a name."), StringLength(80, MinimumLength = 2, ErrorMessage = "Give the role a name.")]
        public string RoleName { get; set; } = "";

        [StringLength(300)]
        public string? Description { get; set; }

        public List<int> PermissionIds { get; set; } = [];
    }

    public sealed record PermissionGroup(string Module, string Group, IReadOnlyList<Permission> Items);

    [BindProperty(SupportsGet = true)]
    public long? Id { get; set; }

    [BindProperty]
    public RoleForm Form { get; set; } = new();

    public RoleHeader? Role { get; private set; }

    public IReadOnlyList<PermissionGroup> Groups { get; private set; } = [];

    public IReadOnlySet<int> Grantable { get; private set; } = new HashSet<int>();

    /// <summary>What the role grants today; a permission it already has may always be removed.</summary>
    public IReadOnlySet<int> Existing { get; private set; } = new HashSet<int>();

    public bool IsNew => Id is null or 0;

    public bool ReadOnly => !Can("Admin.Role.Manage") || Role is { IsEditable: false };

    public async Task<IActionResult> OnGetAsync(CancellationToken ct)
    {
        if (!await LoadAsync(ct)) return NotFound();
        if (Role is not null)
            Form = new RoleForm { RoleName = Role.RoleName, Description = Role.Description, PermissionIds = Existing.ToList() };
        return Page();
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken ct)
    {
        if (!Can("Admin.Role.Manage")) return Forbid();
        if (!await LoadAsync(ct)) return NotFound();
        if (ReadOnly) return Forbid();
        if (!ModelState.IsValid) return Page();

        var result = await team.SaveRoleAsync(TenantId, Id ?? 0, Form.RoleName.Trim(),
            string.IsNullOrWhiteSpace(Form.Description) ? null : Form.Description.Trim(),
            Form.PermissionIds.Distinct(), UserId, IpAddress, ct);
        if (!result.Succeeded)
        {
            ModelState.AddModelError(result.FieldName is null ? "" : "Form." + result.FieldName, result.ResultMessage + ".");
            return Page();
        }

        Flash = IsNew ? $"Created {Form.RoleName}. Assign it from a person's page." : $"Saved {Form.RoleName}. People with it get the change the next time they sign in.";
        return RedirectToPage("/Team/Roles");
    }

    public async Task<IActionResult> OnPostDeleteAsync(CancellationToken ct)
    {
        if (!Can("Admin.Role.Manage") || IsNew) return Forbid();
        var result = await team.DeleteRoleAsync(TenantId, Id!.Value, UserId, IpAddress, ct);
        if (!result.Succeeded)
        {
            Flash = result.ResultMessage + ".";
            return RedirectToPage(new { id = Id });
        }
        Flash = "Role deleted.";
        return RedirectToPage("/Team/Roles");
    }

    private async Task<bool> LoadAsync(CancellationToken ct)
    {
        if (!IsNew)
        {
            var detail = await team.RoleAsync(TenantId, Id!.Value, ct);
            if (detail is null) return false;
            Role = detail.Role;
            Existing = detail.PermissionIds;
        }

        var all = await team.PermissionsAsync(ct);
        Groups = all.GroupBy(p => (p.ModuleName, p.GroupName))
            .Select(g => new PermissionGroup(g.Key.ModuleName, g.Key.GroupName, g.ToList()))
            .ToList();
        Grantable = await team.GrantableAsync(TenantId, UserId, ct);
        return true;
    }
}
