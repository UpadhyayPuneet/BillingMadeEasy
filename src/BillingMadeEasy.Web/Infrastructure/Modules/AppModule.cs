using System.Security.Claims;
using BillingMadeEasy.Core.Tenancy;

namespace BillingMadeEasy.Web.Infrastructure.Modules;

/// <param name="Permission">Needed to see the entry; several codes separated by <c>|</c> mean any of them.</param>
/// <param name="Shortcut">Two-key "go to" chord after <c>g</c>, e.g. <c>d</c> for g→d.</param>
/// <param name="Keywords">Extra words the command bar matches (synonyms people actually type).</param>
public sealed record NavItem(
    string Title,
    string Href,
    string Icon,
    string? Permission = null,
    string? Shortcut = null,
    string Keywords = "",
    string Group = "Go to");

/// <summary>
/// A module plugs itself in: its navigation, command-bar entries and API endpoints. Pages live in
/// <c>Pages/{Folder}</c> and are gated by <c>module:{Key}</c> automatically. Delete a module's
/// class and folder and the app still builds and runs.
/// </summary>
public interface IAppModule
{
    string Key { get; }

    /// <summary>Razor Pages folder owned by this module, or null if it has no pages of its own.</summary>
    string? PagesFolder { get; }

    IEnumerable<NavItem> Navigation { get; }

    void MapEndpoints(IEndpointRouteBuilder api);

    /// <summary>Permission rules for this module's pages (module gating is applied automatically).</summary>
    void ConfigurePages(Microsoft.AspNetCore.Mvc.ApplicationModels.PageConventionCollection conventions) { }
}

public sealed class NavigationService(IEnumerable<IAppModule> modules, EntitlementService entitlements)
{
    public async Task<IReadOnlyList<NavItem>> ForAsync(ClaimsPrincipal user, CancellationToken ct = default)
    {
        if (user.GetTenantId() is not long tenantId) return [];
        var enabled = await entitlements.EnabledModulesAsync(tenantId, ct);

        return modules
            .Where(m => enabled.Contains(m.Key))
            .SelectMany(m => m.Navigation)
            .Where(n => n.Permission is null || n.Permission.Split('|').Any(user.HasPermission))
            .ToList();
    }
}
