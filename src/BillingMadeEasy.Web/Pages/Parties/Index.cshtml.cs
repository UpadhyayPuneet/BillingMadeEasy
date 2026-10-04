using BillingMadeEasy.Core.Parties;
using BillingMadeEasy.Web.Features.Parties;
using BillingMadeEasy.Web.Infrastructure.Pages;
using Microsoft.AspNetCore.Mvc;

namespace BillingMadeEasy.Web.Pages.Parties;

public sealed class IndexModel(PartyStore parties) : TenantPageModel
{
    private const int PageSize = 50;

    [BindProperty(SupportsGet = true)]
    public string? Role { get; set; }

    [BindProperty(SupportsGet = true)]
    public string? Q { get; set; }

    [BindProperty(SupportsGet = true, Name = "p")]
    public int PageNumber { get; set; } = 1;

    public PartyPage Result { get; private set; } = new([], 0, 1, PageSize);

    public byte? RoleType => Role switch
    {
        "customer" => PartyCodes.RoleCustomer,
        "supplier" => PartyCodes.RoleSupplier,
        _ => null,
    };

    public string Title => RoleType switch
    {
        PartyCodes.RoleCustomer => "Customers",
        PartyCodes.RoleSupplier => "Suppliers",
        _ => "Parties",
    };

    public async Task OnGetAsync(CancellationToken ct) => await LoadAsync(ct);

    /// <summary>Just the rows and pager, for search-as-you-type.</summary>
    public async Task<IActionResult> OnGetRowsAsync(CancellationToken ct)
    {
        await LoadAsync(ct);
        return Partial("_PartyRows", this);
    }

    public string PageUrl(int page) =>
        Url.Page("/Parties/Index", new { role = Role, q = string.IsNullOrWhiteSpace(Q) ? null : Q, p = page > 1 ? page : (int?)null })!;

    private async Task LoadAsync(CancellationToken ct)
    {
        Q = string.IsNullOrWhiteSpace(Q) ? null : Q.Trim();
        PageNumber = Math.Max(1, PageNumber);
        Result = await parties.ListAsync(TenantId, RoleType, Q, PageNumber, PageSize, ct);
    }
}
