using BillingMadeEasy.Core.Modules;
using BillingMadeEasy.Web.Infrastructure.Auth;
using BillingMadeEasy.Web.Infrastructure.Modules;
using Microsoft.AspNetCore.Mvc.ApplicationModels;

namespace BillingMadeEasy.Web.Modules;

/// <summary>Customers and suppliers. Part of Essentials: every other module reads from it.</summary>
public sealed class PartiesModule : IAppModule
{
    public const string View = "Party.Customer.View|Party.Supplier.View";
    public const string Manage = "Party.Customer.Manage|Party.Supplier.Manage";

    public string Key => ModuleKeys.Core;

    public string? PagesFolder => "/Parties";

    public IEnumerable<NavItem> Navigation =>
    [
        new("Parties", "/Parties", "groups", View, Shortcut: "c", Keywords: "customers suppliers vendors clients party ledger contacts gstin"),
        new("Customers", "/Parties?role=customer", "person", "Party.Customer.View", Keywords: "clients buyers debtors", Group: "Find"),
        new("Suppliers", "/Parties?role=supplier", "local_shipping", "Party.Supplier.View", Keywords: "vendors creditors", Group: "Find"),
        new("New customer", "/Parties/Edit?role=customer", "person_add", "Party.Customer.Manage", Keywords: "add create client", Group: "Create"),
        new("New supplier", "/Parties/Edit?role=supplier", "add_business", "Party.Supplier.Manage", Keywords: "add create vendor", Group: "Create"),
    ];

    public void MapEndpoints(IEndpointRouteBuilder api) { }

    public void ConfigurePages(PageConventionCollection conventions)
    {
        conventions.AuthorizeFolder("/Parties", Policies.AnyPermission(View.Split('|')));
        conventions.AuthorizePage("/Parties/Edit", Policies.AnyPermission(Manage.Split('|')));
    }
}
