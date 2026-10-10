using BillingMadeEasy.Web.Features.Sales;
using BillingMadeEasy.Web.Infrastructure.Formatting;
using BillingMadeEasy.Web.Infrastructure.Pages;
using Microsoft.AspNetCore.Mvc;

namespace BillingMadeEasy.Web.Pages.Sales.Invoices;

public sealed class IndexModel(InvoiceStore invoices) : TenantPageModel
{
    private const int PageSize = 50;
    private static readonly string[] Views = ["all", "draft", "unpaid", "overdue", "paid", "cancelled"];

    [BindProperty(SupportsGet = true)] public string? View { get; set; }
    [BindProperty(SupportsGet = true)] public string? Q { get; set; }
    [BindProperty(SupportsGet = true, Name = "p")] public int PageNumber { get; set; } = 1;

    public InvoicePage Result { get; private set; } = new([], new InvoiceSummary(), 0, 1, PageSize);

    public string CurrentView => View is not null && Views.Contains(View) ? View : "all";
    public bool CanCreate => Can("Sales.Invoice.Create");

    public async Task OnGetAsync(CancellationToken ct) => await LoadAsync(ct);

    public async Task<IActionResult> OnGetRowsAsync(CancellationToken ct)
    {
        await LoadAsync(ct);
        return Partial("_InvoiceRows", this);
    }

    public string Link(string? view = "", int page = 1) =>
        Url.Page("/Sales/Invoices/Index", new
        {
            view = (view == "" ? CurrentView : view) is "all" or null ? null : (view == "" ? CurrentView : view),
            q = Q,
            p = page > 1 ? page : (int?)null,
        })!;

    private async Task LoadAsync(CancellationToken ct)
    {
        Q = string.IsNullOrWhiteSpace(Q) ? null : Q.Trim();
        PageNumber = Math.Max(1, PageNumber);
        Result = await invoices.ListAsync(TenantId, CurrentView, Q, null, DateOnly.FromDateTime(When.TodayIst()), PageNumber, PageSize, ct);
    }
}
