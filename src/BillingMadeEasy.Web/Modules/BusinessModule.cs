using BillingMadeEasy.Core.Modules;
using BillingMadeEasy.Web.Infrastructure.Auth;
using BillingMadeEasy.Web.Infrastructure.Modules;
using Microsoft.AspNetCore.Mvc.ApplicationModels;

namespace BillingMadeEasy.Web.Modules;

/// <summary>Who the invoices are from: profiles, bank accounts, numbering. Part of Essentials.</summary>
public sealed class BusinessModule : IAppModule
{
    public const string ViewPermission = "Admin.Business.Manage|Setup.Numbering.Manage|Admin.Settings.View";

    public string Key => ModuleKeys.Core;

    public string? PagesFolder => "/Business";

    public IEnumerable<NavItem> Navigation =>
    [
        new("Your business", "/Business", "storefront", ViewPermission, Shortcut: "b",
            Keywords: "company profile gstin pan address logo signature bank account upi ifsc invoice numbering series prefix terms", Group: "Settings"),
    ];

    public void MapEndpoints(IEndpointRouteBuilder api) { }

    public void ConfigurePages(PageConventionCollection conventions)
    {
        conventions.AuthorizeFolder("/Business", Policies.AnyPermission(ViewPermission));
    }
}
