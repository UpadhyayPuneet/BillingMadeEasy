using BillingMadeEasy.Core;
using BillingMadeEasy.Data;

namespace BillingMadeEasy.Web.Features.Team;

public static class MemberStatus
{
    public const byte Active = 2;
    public const byte Suspended = 3;
    public const byte Removed = 4;

    public static string Label(byte status) => status switch
    {
        Active => "Active",
        Suspended => "Suspended",
        Removed => "Removed",
        _ => "Pending",
    };
}

public sealed class MemberRow
{
    public long TenantUserId { get; init; }
    public long UserId { get; init; }
    public byte Status { get; init; }
    public bool IsTenantOwner { get; init; }
    public string? Designation { get; init; }
    public string? EmployeeCode { get; init; }
    public DateTime? InvitedAtUtc { get; init; }
    public DateTime? LastAccessedAtUtc { get; init; }
    public string FullName { get; init; } = "";
    public string Email { get; init; } = "";
    public string? Mobile { get; init; }
    public DateTime? LastLoginAtUtc { get; init; }
    public bool HasPassword { get; init; }
    public string? RoleNames { get; init; }

    /// <summary>Invited but hasn't set a password yet.</summary>
    public bool IsPending => !HasPassword;
}

public sealed record MemberPage(IReadOnlyList<MemberRow> Rows, int Total);

public sealed class Member : ProcResult
{
    public long TenantUserId { get; init; }
    public long UserId { get; init; }
    public byte Status { get; init; }
    public bool IsTenantOwner { get; init; }
    public string? Designation { get; init; }
    public string? EmployeeCode { get; init; }
    public DateTime? InvitedAtUtc { get; init; }
    public DateTime? AcceptedAtUtc { get; init; }
    public DateTime? LastAccessedAtUtc { get; init; }
    public Guid PublicId { get; init; }
    public string FullName { get; init; } = "";
    public string Email { get; init; } = "";
    public string? Mobile { get; init; }
    public string? MobileCountryCode { get; init; }
    public DateTime? LastLoginAtUtc { get; init; }
    public bool HasPassword { get; init; }
    public int OtherTenants { get; init; }
}

public sealed class MemberRole
{
    public long RoleId { get; init; }
    public string RoleCode { get; init; } = "";
    public string RoleName { get; init; } = "";
}

public sealed record MemberDetail(Member Member, IReadOnlyList<MemberRole> Roles);

public sealed class RoleRow
{
    public long RoleId { get; init; }
    public string RoleCode { get; init; } = "";
    public string RoleName { get; init; } = "";
    public string? Description { get; init; }
    public bool IsSystemRole { get; init; }
    public int PermissionCount { get; init; }
    public int MemberCount { get; init; }

    public bool IsOwnerRole => RoleCode == "OWNER";
}

public sealed class RoleHeader : ProcResult
{
    public long RoleId { get; init; }
    public string RoleCode { get; init; } = "";
    public string RoleName { get; init; } = "";
    public string? Description { get; init; }
    public bool IsSystemRole { get; init; }
    public bool IsEditable { get; init; }
    public int MemberCount { get; init; }
}

public sealed record RoleDetail(RoleHeader Role, IReadOnlySet<int> PermissionIds);

public sealed class Permission
{
    public int PermissionId { get; init; }
    public string PermissionCode { get; init; } = "";
    public string ModuleName { get; init; } = "";
    public string GroupName { get; init; } = "";
    public string DisplayName { get; init; } = "";
    public string? Description { get; init; }
}

public sealed class InviteResult : ProcResult
{
    public long TenantUserId { get; init; }
    public long UserId { get; init; }
    public bool IsNewUser { get; init; }
    public Guid PublicId { get; init; }
}

public sealed class RoleSaveResult : ProcResult
{
    public long RoleId { get; init; }
    public string? FieldName { get; init; }
}

public sealed class InviteContext : ProcResult
{
    public long TenantId { get; init; }
    public string TenantName { get; init; } = "";
    public string? InviterName { get; init; }
    public string? RoleNames { get; init; }
}

/// <summary>People and roles, through the usp_Admin_* procedures and their escalation guards.</summary>
public sealed class TeamStore(IDb db)
{
    public Task<MemberPage> ListAsync(long tenantId, string? search, byte? status, int page, int pageSize, CancellationToken ct) =>
        db.MultipleAsync("dbo.usp_Admin_User_List",
            new { TenantId = tenantId, Search = search, Status = status, RoleId = (long?)null, Page = page, PageSize = pageSize },
            async grid => new MemberPage((await grid.ReadAsync<MemberRow>()).ToList(), await grid.ReadSingleAsync<int>()), ct);

    public async Task<MemberDetail?> GetAsync(long tenantId, long tenantUserId, CancellationToken ct)
    {
        var (member, roles) = await db.MultipleAsync("dbo.usp_Admin_User_Get", new { TenantId = tenantId, TenantUserId = tenantUserId },
            async grid => (await grid.ReadSingleOrDefaultAsync<Member>(), (await grid.ReadAsync<MemberRole>()).ToList()), ct);
        return member is { Succeeded: true, TenantUserId: > 0 } ? new MemberDetail(member, roles) : null;
    }

    public Task<InviteResult> InviteAsync(long tenantId, string fullName, string email, string? mobile, string? designation,
        string? employeeCode, IEnumerable<long> roleIds, long byUserId, string? ip, CancellationToken ct) =>
        db.ResultAsync<InviteResult>("dbo.usp_Admin_User_Invite", new
        {
            TenantId = tenantId,
            FullName = fullName,
            Email = email,
            MobileCc = mobile is null ? null : "+91",
            Mobile = mobile,
            Designation = designation,
            EmployeeCode = employeeCode,
            RoleIds = string.Join(',', roleIds),
            InvitedByUserId = byUserId,
            IpAddress = ip,
        }, ct);

    public Task<ProcResult> UpdateAsync(long tenantId, long tenantUserId, string fullName, string? mobile, string? designation,
        string? employeeCode, IEnumerable<long> roleIds, long byUserId, string? ip, CancellationToken ct) =>
        db.ResultAsync<ProcResult>("dbo.usp_Admin_User_Update", new
        {
            TenantId = tenantId,
            TenantUserId = tenantUserId,
            FullName = fullName,
            MobileCc = mobile is null ? null : "+91",
            Mobile = mobile,
            Designation = designation,
            EmployeeCode = employeeCode,
            RoleIds = string.Join(',', roleIds),
            UpdatedBy = byUserId,
            IpAddress = ip,
        }, ct);

    public Task<ProcResult> SetStatusAsync(long tenantId, long tenantUserId, byte status, long byUserId, string? ip, CancellationToken ct) =>
        db.ResultAsync<ProcResult>("dbo.usp_Admin_User_SetStatus",
            new { TenantId = tenantId, TenantUserId = tenantUserId, Status = status, ActionByUserId = byUserId, IpAddress = ip }, ct);

    public Task<ProcResult> SetOwnerAsync(long tenantId, long tenantUserId, bool isOwner, long byUserId, string? ip, CancellationToken ct) =>
        db.ResultAsync<ProcResult>("dbo.usp_Admin_User_SetOwner",
            new { TenantId = tenantId, TenantUserId = tenantUserId, IsOwner = isOwner, ActionByUserId = byUserId, IpAddress = ip }, ct);

    public Task<IReadOnlyList<RoleRow>> RolesAsync(long tenantId, CancellationToken ct) =>
        db.ListAsync<RoleRow>("dbo.usp_Admin_Role_List", new { TenantId = tenantId }, ct);

    public async Task<RoleDetail?> RoleAsync(long tenantId, long roleId, CancellationToken ct)
    {
        var (header, ids) = await db.MultipleAsync("dbo.usp_Admin_Role_Get", new { TenantId = tenantId, RoleId = roleId },
            async grid => (await grid.ReadSingleOrDefaultAsync<RoleHeader>(), (await grid.ReadAsync<int>()).ToHashSet()), ct);
        return header is { Succeeded: true, RoleId: > 0 } ? new RoleDetail(header, ids) : null;
    }

    public Task<RoleSaveResult> SaveRoleAsync(long tenantId, long roleId, string name, string? description, IEnumerable<int> permissionIds,
        long byUserId, string? ip, CancellationToken ct) =>
        db.ResultAsync<RoleSaveResult>("dbo.usp_Admin_Role_Save", new
        {
            TenantId = tenantId,
            RoleId = roleId,
            RoleName = name,
            Description = description,
            PermissionIds = string.Join(',', permissionIds),
            ActionByUserId = byUserId,
            IpAddress = ip,
        }, ct);

    public Task<ProcResult> DeleteRoleAsync(long tenantId, long roleId, long byUserId, string? ip, CancellationToken ct) =>
        db.ResultAsync<ProcResult>("dbo.usp_Admin_Role_Delete", new { TenantId = tenantId, RoleId = roleId, ActionByUserId = byUserId, IpAddress = ip }, ct);

    public Task<IReadOnlyList<Permission>> PermissionsAsync(CancellationToken ct) =>
        db.ListAsync<Permission>("dbo.usp_Admin_Permission_List", null, ct);

    public async Task<IReadOnlySet<int>> GrantableAsync(long tenantId, long userId, CancellationToken ct) =>
        (await db.ListAsync<int>("dbo.usp_Admin_Permission_GrantableBy", new { TenantId = tenantId, UserId = userId }, ct)).ToHashSet();

    private sealed class Membership
    {
        public long TenantId { get; init; }
        public bool IsTenantOwner { get; init; }
    }

    /// <summary>Whether the acting user is an owner of this business (only owners grant Owner).</summary>
    public async Task<bool> IsOwnerAsync(long tenantId, long userId, CancellationToken ct) =>
        (await db.ListAsync<Membership>("dbo.usp_Auth_UserTenants_Get", new { UserId = userId }, ct))
        .Any(m => m.TenantId == tenantId && m.IsTenantOwner);

    public Task<InviteContext?> InviteContextAsync(long userId, CancellationToken ct) =>
        db.SingleAsync<InviteContext>("dbo.usp_Auth_Invite_GetContext", new { UserId = userId }, ct);

    public Task<ProcResult> SetPasswordAsync(long userId, string hash, long? tenantId, string? ip, CancellationToken ct) =>
        db.ResultAsync<ProcResult>("dbo.usp_Auth_Password_Set", new
        {
            UserId = userId,
            NewPasswordHash = hash,
            ChangedByUserId = userId,
            ChangeReason = (byte)4,
            TenantId = tenantId,
            IpAddress = ip,
            EndOtherSessions = true,
        }, ct);
}
