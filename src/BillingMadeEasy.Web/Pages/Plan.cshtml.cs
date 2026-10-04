using BillingMadeEasy.Core.Modules;
using BillingMadeEasy.Core.Tenancy;
using BillingMadeEasy.Web.Infrastructure.Modules;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BillingMadeEasy.Web.Pages;

public sealed record ModuleRow(ModuleDescriptor Module, bool Enabled, EntitlementSource? Source, DateTimeOffset? ExpiresAt, IReadOnlyList<string> Missing);

public sealed class PlanModel(EntitlementService entitlements, TimeProvider clock) : PageModel
{
    [BindProperty(SupportsGet = true)]
    public string? Need { get; set; }

    public string PlanCode { get; private set; } = "";
    public IReadOnlyList<ModuleRow> Rows { get; private set; } = [];
    public ModuleDescriptor? Needed => Need is null ? null : ModuleCatalog.Find(Need);

    public async Task OnGetAsync(CancellationToken ct)
    {
        var tenant = await entitlements.GetAsync(User.GetTenantId()!.Value, ct);
        var enabled = tenant.EnabledModules(clock.GetUtcNow());
        PlanCode = tenant.PlanCode;

        Rows = ModuleCatalog.All
            .Where(m => !m.IsCore)
            .Select(m =>
            {
                var grant = tenant.Grants.FirstOrDefault(g => string.Equals(g.ModuleKey, m.Key, StringComparison.OrdinalIgnoreCase));
                return new ModuleRow(m, enabled.Contains(m.Key), grant?.Source, grant?.ExpiresAt, ModuleCatalog.MissingRequirements(m.Key, enabled));
            })
            .OrderByDescending(r => r.Enabled).ThenByDescending(r => r.Module.IsAvailable)
            .ToList();
    }
}
