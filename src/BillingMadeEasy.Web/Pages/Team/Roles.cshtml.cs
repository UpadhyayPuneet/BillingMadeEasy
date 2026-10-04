using BillingMadeEasy.Web.Features.Team;
using BillingMadeEasy.Web.Infrastructure.Pages;

namespace BillingMadeEasy.Web.Pages.Team;

public sealed class RolesModel(TeamStore team) : TenantPageModel
{
    public IReadOnlyList<RoleRow> Roles { get; private set; } = [];

    public async Task OnGetAsync(CancellationToken ct) => Roles = await team.RolesAsync(TenantId, ct);
}
