using BillingMadeEasy.Web.Features.Sales;
using BillingMadeEasy.Web.Infrastructure.Formatting;
using BillingMadeEasy.Web.Infrastructure.Pages;
using Microsoft.AspNetCore.Mvc;

namespace BillingMadeEasy.Web.Pages.Sales.Payments;

public sealed class IndexModel(PaymentStore payments) : TenantPageModel
{
    private const int PageSize = 50;
    private static readonly string[] Views = ["all", "advance", "reversed"];

    [BindProperty(SupportsGet = true)] public string? View { get; set; }
    [BindProperty(SupportsGet = true)] public string? Q { get; set; }
    [BindProperty(SupportsGet = true, Name = "p")] public int PageNumber { get; set; } = 1;

    public PaymentPage Result { get; private set; } = new([], new PaymentSummary(), 0, 1, PageSize);
    public string CurrentView => View is not null && Views.Contains(View) ? View : "all";
    public bool CanRecord => Can("Sales.Payment.Record");

    public async Task OnGetAsync(CancellationToken ct) => await LoadAsync(ct);

    public async Task<IActionResult> OnGetRowsAsync(CancellationToken ct)
    {
        await LoadAsync(ct);
        return Partial("_PaymentRows", this);
    }

    public string Link(string? view = "", int page = 1)
    {
        string v = view == "" ? CurrentView : view ?? "all";
        return Url.Page("/Sales/Payments/Index", new { view = v == "all" ? null : v, q = Q, p = page > 1 ? page : (int?)null })!;
    }

    private async Task LoadAsync(CancellationToken ct)
    {
        Q = string.IsNullOrWhiteSpace(Q) ? null : Q.Trim();
        PageNumber = Math.Max(1, PageNumber);
        Result = await payments.ListAsync(TenantId, CurrentView, Q, null, DateOnly.FromDateTime(When.TodayIst()), PageNumber, PageSize, ct);
    }
}
