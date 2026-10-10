using BillingMadeEasy.Web.Features.Business;
using BillingMadeEasy.Web.Infrastructure.Pages;

namespace BillingMadeEasy.Web.Pages.Business;

public sealed class IndexModel(BusinessStore business) : TenantPageModel
{
    public IReadOnlyList<ProfileRow> Profiles { get; private set; } = [];

    public bool CanEdit => Can("Admin.Business.Manage");

    public async Task OnGetAsync(CancellationToken ct) => Profiles = await business.ListAsync(TenantId, ct);
}
