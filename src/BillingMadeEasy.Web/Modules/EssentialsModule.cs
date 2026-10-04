using BillingMadeEasy.Core.Modules;
using BillingMadeEasy.Core.Tax;
using BillingMadeEasy.Web.Infrastructure.Modules;

namespace BillingMadeEasy.Web.Modules;

public sealed class EssentialsModule : IAppModule
{
    public string Key => ModuleKeys.Core;

    public string? PagesFolder => null;

    public IEnumerable<NavItem> Navigation =>
    [
        new("Home", "/", "space_dashboard", Shortcut: "h", Keywords: "dashboard start overview"),
        new("Plan & modules", "/Plan", "extension", Shortcut: "p", Keywords: "subscription add-on upgrade billing plan modules"),
        new("GSTIN check", "/Tools/Gstin", "verified", Shortcut: "t", Keywords: "gst tax number validate verify state pan", Group: "Tools"),
    ];

    public void MapEndpoints(IEndpointRouteBuilder api)
    {
        var group = api.MapGroup("/core");

        group.MapGet("/gstin/{value}", (string value) =>
        {
            var check = Gstin.Check(value);
            string normalized = Gstin.Normalize(value);
            bool valid = check == GstinCheck.Valid;
            return Results.Ok(new
            {
                gstin = normalized,
                valid,
                reason = check.ToString(),
                stateCode = valid ? Gstin.StateCode(normalized) : null,
                state = valid ? StateCodes.Name(Gstin.StateCode(normalized)) : null,
                pan = valid ? Gstin.Pan(normalized) : null,
            });
        });
    }
}
