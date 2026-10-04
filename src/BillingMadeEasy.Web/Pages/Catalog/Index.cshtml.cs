using BillingMadeEasy.Web.Features.Catalog;
using BillingMadeEasy.Web.Infrastructure.Pages;
using Microsoft.AspNetCore.Mvc;

namespace BillingMadeEasy.Web.Pages.Catalog;

public sealed class IndexModel(CatalogStore catalog) : TenantPageModel
{
    private const int PageSize = 50;

    [BindProperty(SupportsGet = true)] public string? Type { get; set; }
    [BindProperty(SupportsGet = true)] public string? Q { get; set; }
    [BindProperty(SupportsGet = true)] public bool Hidden { get; set; }
    [BindProperty(SupportsGet = true, Name = "p")] public int PageNumber { get; set; } = 1;

    public OfferingPage Result { get; private set; } = new([], 0, 1, PageSize);

    public byte? TypeCode => Type switch
    {
        "product" => OfferingType.Product,
        "service" => OfferingType.Service,
        "expense" => OfferingType.Expense,
        _ => null,
    };

    public bool CanSeePrices => Can("Catalog.Price.View");

    public async Task OnGetAsync(CancellationToken ct) => await LoadAsync(ct);

    public async Task<IActionResult> OnGetRowsAsync(CancellationToken ct)
    {
        await LoadAsync(ct);
        return Partial("_ItemRows", this);
    }

    public string Link(string? type = "", int page = 1, bool? hidden = null) =>
        Url.Page("/Catalog/Index", new
        {
            type = type == "" ? Type : type,
            q = Q,
            hidden = (hidden ?? Hidden) ? true : (bool?)null,
            p = page > 1 ? page : (int?)null,
        })!;

    private async Task LoadAsync(CancellationToken ct)
    {
        Q = string.IsNullOrWhiteSpace(Q) ? null : Q.Trim();
        PageNumber = Math.Max(1, PageNumber);
        Result = await catalog.ListAsync(TenantId, TypeCode, Q, Hidden, PageNumber, PageSize, ct);
    }
}
