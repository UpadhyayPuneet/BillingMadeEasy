using BillingMadeEasy.Core.Tenancy;
using BillingMadeEasy.Core.Modules;
using BillingMadeEasy.Web.Features.Catalog;
using BillingMadeEasy.Web.Infrastructure.Auth;
using BillingMadeEasy.Web.Infrastructure.Modules;
using Microsoft.AspNetCore.Mvc.ApplicationModels;

namespace BillingMadeEasy.Web.Modules;

/// <summary>Products, services and expenses. Part of Essentials: invoices and purchases read from it.</summary>
public sealed class CatalogModule : IAppModule
{
    public string Key => ModuleKeys.Core;

    public string? PagesFolder => "/Catalog";

    public IEnumerable<NavItem> Navigation =>
    [
        new("Catalog", "/Catalog", "inventory_2", "Catalog.Offering.View", Shortcut: "i", Keywords: "items products services sku price list hsn sac"),
        new("Products", "/Catalog?type=product", "category", "Catalog.Offering.View", Keywords: "goods stock sku", Group: "Find"),
        new("Services", "/Catalog?type=service", "design_services", "Catalog.Offering.View", Keywords: "sac work hours", Group: "Find"),
        new("New product", "/Catalog/Item?type=product", "add_box", "Catalog.Offering.Manage", Keywords: "add create item sku goods", Group: "Create"),
        new("New service", "/Catalog/Item?type=service", "add_task", "Catalog.Offering.Manage", Keywords: "add create item sac", Group: "Create"),
    ];

    public void MapEndpoints(IEndpointRouteBuilder api)
    {
        // Brand typeahead: shows the brand that already exists before someone types a second one.
        api.MapGet("/catalog/brands", async (string? q, HttpContext http, CatalogStore store, CancellationToken ct) =>
            Results.Ok(await store.SearchBrandsAsync(http.User.GetTenantIdOrThrow(), q, ct)))
            .RequireAuthorization(Policies.Permission("Catalog.Offering.View"));
    }

    public void ConfigurePages(PageConventionCollection conventions)
    {
        conventions.AuthorizeFolder("/Catalog", Policies.Permission("Catalog.Offering.View"));
    }
}
