using BillingMadeEasy.Core.Tenancy;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BillingMadeEasy.Web.Infrastructure.Pages;

/// <summary>
/// Base for pages inside a business. Tenant and user always come from the authenticated session,
/// never from the request, so a tampered form can't reach another business's data.
/// </summary>
public abstract class TenantPageModel : PageModel
{
    protected long TenantId => User.GetTenantId() ?? throw new InvalidOperationException("No business selected.");

    protected long UserId => User.GetUserId() ?? throw new InvalidOperationException("Not signed in.");

    protected string? IpAddress => HttpContext.Connection.RemoteIpAddress?.ToString();

    public bool Can(string permission) => User.HasPermission(permission);

    /// <summary>One-shot message shown on the next page (after a redirect).</summary>
    [Microsoft.AspNetCore.Mvc.TempData]
    public string? Flash { get; set; }
}
