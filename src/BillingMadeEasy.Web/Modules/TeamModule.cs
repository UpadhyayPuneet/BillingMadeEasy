using BillingMadeEasy.Core.Modules;
using BillingMadeEasy.Web.Infrastructure.Auth;
using BillingMadeEasy.Web.Infrastructure.Modules;
using Microsoft.AspNetCore.Mvc.ApplicationModels;

namespace BillingMadeEasy.Web.Modules;

/// <summary>People and roles. Part of Essentials.</summary>
public sealed class TeamModule : IAppModule
{
    public string Key => ModuleKeys.Core;

    public string? PagesFolder => "/Team";

    public IEnumerable<NavItem> Navigation =>
    [
        new("Team", "/Team", "badge", "Admin.User.View", Shortcut: "u", Keywords: "users people staff employees members access", Group: "Settings"),
        new("Invite someone", "/Team/Invite", "person_add", "Admin.User.Manage", Keywords: "add user staff employee invite", Group: "Create"),
        new("Roles & permissions", "/Team/Roles", "admin_panel_settings", "Admin.Role.View", Shortcut: "r", Keywords: "roles access rights permissions security", Group: "Settings"),
    ];

    public void MapEndpoints(IEndpointRouteBuilder api) { }

    public void ConfigurePages(PageConventionCollection conventions)
    {
        conventions.AuthorizePage("/Team/Index", Policies.Permission("Admin.User.View"));
        conventions.AuthorizePage("/Team/Member", Policies.Permission("Admin.User.View"));
        conventions.AuthorizePage("/Team/Invite", Policies.Permission("Admin.User.Manage"));
        conventions.AuthorizePage("/Team/Roles", Policies.Permission("Admin.Role.View"));
        conventions.AuthorizePage("/Team/Role", Policies.Permission("Admin.Role.View"));
    }
}
