using BillingMadeEasy.Web.Features.Team;
using BillingMadeEasy.Web.Infrastructure.Pages;
using Microsoft.AspNetCore.Mvc;

namespace BillingMadeEasy.Web.Pages.Team;

public sealed class IndexModel(TeamStore team) : TenantPageModel
{
    private const int PageSize = 100;

    [BindProperty(SupportsGet = true)]
    public string? Q { get; set; }

    [BindProperty(SupportsGet = true)]
    public string? Show { get; set; }

    public MemberPage Result { get; private set; } = new([], 0);

    public byte? Status => Show switch
    {
        "suspended" => MemberStatus.Suspended,
        "removed" => MemberStatus.Removed,
        _ => null,
    };

    public async Task OnGetAsync(CancellationToken ct) => await LoadAsync(ct);

    public async Task<IActionResult> OnGetRowsAsync(CancellationToken ct)
    {
        await LoadAsync(ct);
        return Partial("_MemberRows", this);
    }

    private async Task LoadAsync(CancellationToken ct)
    {
        Q = string.IsNullOrWhiteSpace(Q) ? null : Q.Trim();
        Result = await team.ListAsync(TenantId, Q, Status, 1, PageSize, ct);
    }
}
