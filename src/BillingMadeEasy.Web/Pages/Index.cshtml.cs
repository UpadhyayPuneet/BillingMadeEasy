using System.Security.Claims;
using BillingMadeEasy.Core.Modules;
using BillingMadeEasy.Core.Tenancy;
using BillingMadeEasy.Web.Infrastructure.Modules;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BillingMadeEasy.Web.Pages;

public sealed class IndexModel(NavigationService navigation, EntitlementService entitlements, TimeProvider clock) : PageModel
{
    public string Greeting { get; private set; } = "";
    public string FirstName { get; private set; } = "";
    public IReadOnlyList<NavItem> Shortcuts { get; private set; } = [];
    public IReadOnlyList<ModuleDescriptor> Modules { get; private set; } = [];

    public async Task OnGetAsync(CancellationToken ct)
    {
        int hour = clock.GetLocalNow().Hour;
        Greeting = hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening";
        FirstName = (User.FindFirstValue(ClaimTypes.Name) ?? "").Split(' ', 2)[0];
        Shortcuts = (await navigation.ForAsync(User, ct)).Where(n => n.Href != "/").ToList();

        var enabled = await entitlements.EnabledModulesAsync(User.GetTenantId()!.Value, ct);
        Modules = ModuleCatalog.All.Where(m => !m.IsCore && enabled.Contains(m.Key)).ToList();
    }
}
