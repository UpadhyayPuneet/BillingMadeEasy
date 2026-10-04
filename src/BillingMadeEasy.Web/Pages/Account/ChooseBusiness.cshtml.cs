using BillingMadeEasy.Core.Tenancy;
using BillingMadeEasy.Web.Infrastructure.Auth;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BillingMadeEasy.Web.Pages.Account;

public sealed class ChooseBusinessModel(IAuthService auth) : PageModel
{
    public IReadOnlyList<TenantMembership> Tenants { get; private set; } = [];

    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    public long? CurrentTenantId => User.GetTenantId();

    public async Task<IActionResult> OnGetAsync(CancellationToken ct)
    {
        Tenants = await auth.GetTenantsAsync(User.GetUserId()!.Value, ct);
        return Page();
    }

    public async Task<IActionResult> OnPostAsync(long tenantId, CancellationToken ct)
    {
        var session = await auth.SelectTenantAsync(User.GetUserId()!.Value, tenantId, ct);
        if (session is null) return Forbid();

        var current = await HttpContext.AuthenticateAsync();
        await SessionSignIn.SignInTenantAsync(HttpContext, User, session, current.Properties?.IsPersistent ?? false);
        return LocalRedirect(Url.IsLocalUrl(ReturnUrl) ? ReturnUrl! : "/");
    }
}
