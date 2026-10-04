using BillingMadeEasy.Core.Tenancy;
using BillingMadeEasy.Web.Infrastructure.Modules;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Authorization.Policy;
using Microsoft.Extensions.Options;

namespace BillingMadeEasy.Web.Infrastructure.Auth;

/// <summary>
/// Policy names are data, not registrations: <c>module:billing</c>, <c>perm:Sales.Invoice.Issue</c>.
/// A new module or permission needs no change here.
/// </summary>
public static class Policies
{
    /// <summary>Signed in, but may not have picked a business yet (the chooser page).</summary>
    public const string SignedIn = "signed-in";
    public const string PlatformAdmin = "platform-admin";
    public const string ModulePrefix = "module:";
    public const string PermissionPrefix = "perm:";
    public const string AnyPermissionPrefix = "anyperm:";

    public static string Module(string key) => ModulePrefix + key;
    public static string Permission(string code) => PermissionPrefix + code;

    /// <summary>Passes when the user holds at least one of the codes.</summary>
    public static string AnyPermission(params string[] codes) => AnyPermissionPrefix + string.Join('|', codes);
}

public sealed class TenantSelectedRequirement : IAuthorizationRequirement;

public sealed record ModuleRequirement(string ModuleKey) : IAuthorizationRequirement;

public sealed record PermissionRequirement(string Code) : IAuthorizationRequirement;

public sealed record AnyPermissionRequirement(IReadOnlyList<string> Codes) : IAuthorizationRequirement;

public sealed class PolicyProvider(IOptions<AuthorizationOptions> options) : DefaultAuthorizationPolicyProvider(options)
{
    public override async Task<AuthorizationPolicy?> GetPolicyAsync(string policyName)
    {
        if (policyName.StartsWith(Policies.ModulePrefix, StringComparison.Ordinal))
            return Tenant().AddRequirements(new ModuleRequirement(policyName[Policies.ModulePrefix.Length..])).Build();

        if (policyName.StartsWith(Policies.PermissionPrefix, StringComparison.Ordinal))
            return Tenant().AddRequirements(new PermissionRequirement(policyName[Policies.PermissionPrefix.Length..])).Build();

        if (policyName.StartsWith(Policies.AnyPermissionPrefix, StringComparison.Ordinal))
            return Tenant().AddRequirements(new AnyPermissionRequirement(
                policyName[Policies.AnyPermissionPrefix.Length..].Split('|', StringSplitOptions.RemoveEmptyEntries))).Build();

        return await base.GetPolicyAsync(policyName);
    }

    private static AuthorizationPolicyBuilder Tenant() =>
        new AuthorizationPolicyBuilder().RequireAuthenticatedUser().AddRequirements(new TenantSelectedRequirement());
}

public sealed class TenantSelectedHandler : AuthorizationHandler<TenantSelectedRequirement>
{
    protected override Task HandleRequirementAsync(AuthorizationHandlerContext context, TenantSelectedRequirement requirement)
    {
        if (context.User.GetTenantId() is not null) context.Succeed(requirement);
        return Task.CompletedTask;
    }
}

public sealed class ModuleHandler(EntitlementService entitlements) : AuthorizationHandler<ModuleRequirement>
{
    protected override async Task HandleRequirementAsync(AuthorizationHandlerContext context, ModuleRequirement requirement)
    {
        if (context.User.GetTenantId() is long tenantId && await entitlements.IsEnabledAsync(tenantId, requirement.ModuleKey))
            context.Succeed(requirement);
    }
}

public sealed class PermissionHandler : AuthorizationHandler<PermissionRequirement>
{
    protected override Task HandleRequirementAsync(AuthorizationHandlerContext context, PermissionRequirement requirement)
    {
        if (context.User.HasPermission(requirement.Code)) context.Succeed(requirement);
        return Task.CompletedTask;
    }
}

public sealed class AnyPermissionHandler : AuthorizationHandler<AnyPermissionRequirement>
{
    protected override Task HandleRequirementAsync(AuthorizationHandlerContext context, AnyPermissionRequirement requirement)
    {
        if (requirement.Codes.Any(context.User.HasPermission)) context.Succeed(requirement);
        return Task.CompletedTask;
    }
}

/// <summary>
/// Turns a failed check into the right next step instead of a bare 403: no business picked → the
/// chooser; module not in the plan → the plan page with that module highlighted (where it can be
/// added). APIs get a problem response they can show inline.
/// </summary>
public sealed class FriendlyAuthorizationResultHandler : IAuthorizationMiddlewareResultHandler
{
    private readonly AuthorizationMiddlewareResultHandler _default = new();

    public async Task HandleAsync(RequestDelegate next, HttpContext context, AuthorizationPolicy policy, PolicyAuthorizationResult result)
    {
        if (result.Forbidden && result.AuthorizationFailure is { } failure)
        {
            bool isApi = context.Request.Path.StartsWithSegments("/api");

            if (failure.FailedRequirements.OfType<TenantSelectedRequirement>().Any())
            {
                await Respond(context, isApi, StatusCodes.Status403Forbidden, "Choose a business first.", "/Account/ChooseBusiness");
                return;
            }

            if (failure.FailedRequirements.OfType<ModuleRequirement>().FirstOrDefault() is { } module)
            {
                await Respond(context, isApi, StatusCodes.Status403Forbidden,
                    $"The {module.ModuleKey} module isn't switched on for this business.", $"/Plan?need={Uri.EscapeDataString(module.ModuleKey)}");
                return;
            }
        }

        await _default.HandleAsync(next, context, policy, result);
    }

    private static async Task Respond(HttpContext context, bool isApi, int status, string detail, string location)
    {
        if (!isApi)
        {
            context.Response.Redirect(location);
            return;
        }

        await Results.Problem(detail: detail, statusCode: status, extensions: new Dictionary<string, object?> { ["action"] = location })
            .ExecuteAsync(context);
    }
}
