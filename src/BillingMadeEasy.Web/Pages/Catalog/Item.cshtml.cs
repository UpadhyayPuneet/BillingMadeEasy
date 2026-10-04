using System.ComponentModel.DataAnnotations;
using BillingMadeEasy.Core.Tax;
using BillingMadeEasy.Web.Features.Catalog;
using BillingMadeEasy.Web.Features.Parties;
using BillingMadeEasy.Web.Infrastructure.Pages;
using Microsoft.AspNetCore.Mvc;

namespace BillingMadeEasy.Web.Pages.Catalog;

public sealed class ItemModel(CatalogStore catalog, PartyStore parties) : TenantPageModel
{
    public sealed class ItemForm
    {
        public byte OfferingType { get; set; } = Features.Catalog.OfferingType.Product;

        [Required(ErrorMessage = "Enter a name."), StringLength(200, MinimumLength = 2, ErrorMessage = "Enter a name.")]
        public string OfferingName { get; set; } = "";

        [StringLength(40)] public string? OfferingCode { get; set; }
        [StringLength(1000)] public string? Description { get; set; }
        public long? CategoryId { get; set; }
        [StringLength(80)] public string? BrandName { get; set; }
        public long? UnitId { get; set; }
        public long? TaxRateId { get; set; }
        [StringLength(12)] public string? HsnSacCode { get; set; }
        [Range(0, 999_999_999_999, ErrorMessage = "Enter a positive amount.")] public decimal? DefaultPrice { get; set; }
        [Range(0, 999_999_999_999, ErrorMessage = "Enter a positive amount.")] public decimal? DefaultCost { get; set; }
        public bool IsPriceInclusive { get; set; }
        public bool IsPureAgent { get; set; }
        public bool IsRecurring { get; set; }
        public bool IsSellable { get; set; } = true;
        public bool IsPurchasable { get; set; }
        [StringLength(50)] public string? Barcode { get; set; }
        [StringLength(40)] public string? PackSize { get; set; }
        public bool TracksStock { get; set; }
        [Range(0, 999_999_999, ErrorMessage = "Enter a positive quantity.")] public decimal? ReorderLevel { get; set; }
    }

    [BindProperty(SupportsGet = true)] public long? Id { get; set; }
    [BindProperty] public ItemForm Form { get; set; } = new();

    public Offering? Existing { get; private set; }
    public IReadOnlyList<UnitOption> Units { get; private set; } = [];
    public IReadOnlyList<TaxOption> TaxRates { get; private set; } = [];
    public IReadOnlyList<CategoryOption> Categories { get; private set; } = [];
    public IReadOnlyList<CustomerPrice> CustomerPrices { get; private set; } = [];

    public bool IsNew => Id is null or 0;
    public bool CanEdit => Can("Catalog.Offering.Manage");
    public bool CanSeePrice => Can("Catalog.Price.View");
    public bool CanEditPrice => Can("Catalog.Price.Manage");
    public bool CanSeeCost => Can("Catalog.Cost.View");

    public async Task<IActionResult> OnGetAsync(string? type, string? name, CancellationToken ct)
    {
        if (!IsNew)
        {
            Existing = await catalog.GetAsync(TenantId, Id!.Value, ct);
            if (Existing is null) return NotFound();
            Form = FromOffering(Existing);
        }
        else
        {
            if (!CanEdit) return Forbid();
            Form.OfferingType = type switch { "service" => OfferingType.Service, "expense" => OfferingType.Expense, _ => OfferingType.Product };
            Form.OfferingName = name?.Trim() ?? "";
            Form.IsRecurring = false;
            Form.IsSellable = Form.OfferingType != OfferingType.Expense;
            Form.IsPurchasable = Form.OfferingType == OfferingType.Expense;
        }
        await LoadLookupsAsync(ct);
        if (IsNew)
        {
            // Sensible starting points: 18% is the most common rate; services are counted in "Service", goods in pieces.
            Form.TaxRateId = TaxRates.FirstOrDefault(t => t.IsDefault)?.TaxRateId;
            Form.UnitId = Units.FirstOrDefault(u => u.UnitCode == (Form.OfferingType == OfferingType.Product ? "pc" : "svc"))?.UnitId;
        }
        return Page();
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken ct)
    {
        if (!CanEdit) return Forbid();
        if (!IsNew)
        {
            Existing = await catalog.GetAsync(TenantId, Id!.Value, ct);
            if (Existing is null) return NotFound();
            // Fields this person may not change keep their stored values.
            if (!CanEditPrice) { Form.DefaultPrice = Existing.DefaultPrice; Form.IsPriceInclusive = Existing.IsPriceInclusive; }
            if (!CanSeeCost) Form.DefaultCost = Existing.DefaultCost;
        }
        else
        {
            if (!CanEditPrice) Form.DefaultPrice = null;
            if (!CanSeeCost) Form.DefaultCost = null;
        }

        bool isService = Form.OfferingType == OfferingType.Service;
        Form.HsnSacCode = Hsn.Normalize(Form.HsnSacCode);
        if (Hsn.Problem(Form.HsnSacCode, isService) is { } hsnProblem) ModelState.AddModelError("Form.HsnSacCode", hsnProblem);
        if (Form.IsPureAgent)
        {
            if (!isService) ModelState.AddModelError("Form.IsPureAgent", "Only a service can be a pure-agent reimbursement.");
            Form.TaxRateId = null;
        }
        if (Form.OfferingType != OfferingType.Product) { Form.Barcode = null; Form.PackSize = null; Form.TracksStock = false; Form.ReorderLevel = null; }
        if (!Form.IsSellable && !Form.IsPurchasable) ModelState.AddModelError("Form.IsSellable", "Tick whether you sell it, buy it, or both.");

        if (!ModelState.IsValid)
        {
            await LoadLookupsAsync(ct);
            return Page();
        }

        var result = await catalog.SaveAsync(new
        {
            TenantId,
            OfferingId = Id ?? 0,
            Form.OfferingType,
            OfferingName = Form.OfferingName.Trim(),
            OfferingCode = Blank(Form.OfferingCode),
            Description = Blank(Form.Description),
            Form.CategoryId,
            BrandName = Blank(Form.BrandName),
            Form.UnitId,
            Form.TaxRateId,
            Form.DefaultPrice,
            Form.DefaultCost,
            Form.IsPriceInclusive,
            Form.IsPureAgent,
            Form.HsnSacCode,
            Form.IsRecurring,
            Form.IsSellable,
            Form.IsPurchasable,
            Barcode = Blank(Form.Barcode),
            PackSize = Blank(Form.PackSize),
            Form.TracksStock,
            Form.ReorderLevel,
            ActionByUserId = UserId,
            IpAddress,
        }, ct);

        if (!result.Succeeded)
        {
            ModelState.AddModelError(result.FieldName is null ? "" : "Form." + result.FieldName, result.ResultMessage + ".");
            await LoadLookupsAsync(ct);
            return Page();
        }

        Flash = result.IsNew ? $"Added {Form.OfferingName}." : "Saved.";
        return RedirectToPage(new { id = result.OfferingId });
    }

    public async Task<IActionResult> OnPostActiveAsync(bool active, CancellationToken ct)
    {
        if (!CanEdit || IsNew) return Forbid();
        var result = await catalog.SetActiveAsync(TenantId, Id!.Value, active, UserId, IpAddress, ct);
        Flash = !result.Succeeded ? result.ResultMessage
            : active ? "Restored. It appears in pickers again."
            : "Hidden. It no longer appears when raising invoices; past documents still show it.";
        return RedirectToPage(new { id = Id });
    }

    public async Task<IActionResult> OnPostCustomerPriceAsync(long partyId, decimal minQuantity, decimal? price, decimal? discountPercent, CancellationToken ct)
    {
        if (!CanEditPrice || IsNew) return Forbid();
        var result = await catalog.SetCustomerPriceAsync(TenantId, Id!.Value, partyId, minQuantity <= 0 ? 1 : minQuantity, price, discountPercent, UserId, IpAddress, ct);
        Flash = result.Succeeded ? "Customer price saved. New invoices for them use it automatically." : result.ResultMessage + ".";
        return Redirect($"/Catalog/Item/{Id}#customer-prices");
    }

    public async Task<IActionResult> OnPostRemovePriceAsync(long itemId, CancellationToken ct)
    {
        if (!CanEditPrice || IsNew) return Forbid();
        var result = await catalog.RemoveCustomerPriceAsync(TenantId, itemId, UserId, IpAddress, ct);
        Flash = result.Succeeded ? "Customer price removed. They'll get the standard price." : result.ResultMessage + ".";
        return Redirect($"/Catalog/Item/{Id}#customer-prices");
    }

    /// <summary>Adds a category without leaving the form; returns it for the picker.</summary>
    public async Task<IActionResult> OnPostCategoryAsync(string name, CancellationToken ct)
    {
        if (!CanEdit) return Forbid();
        var result = await catalog.AddCategoryAsync(TenantId, name ?? "", UserId, IpAddress, ct);
        return result.Succeeded
            ? new JsonResult(new { id = result.CategoryId, name = name!.Trim() })
            : new JsonResult(new { error = result.ResultMessage }) { StatusCode = 400 };
    }

    /// <summary>Customers matching what's typed, for the customer-price picker.</summary>
    public async Task<IActionResult> OnGetCustomersAsync(string? q, CancellationToken ct)
    {
        var page = await parties.ListAsync(TenantId, Core.Parties.PartyCodes.RoleCustomer, q, 1, 8, ct);
        return new JsonResult(page.Rows.Select(p => new { id = p.PartyId, name = p.DisplayName, city = p.PrimaryCity }));
    }

    private async Task LoadLookupsAsync(CancellationToken ct)
    {
        Units = await catalog.UnitsAsync(TenantId, ct);
        TaxRates = await catalog.TaxRatesAsync(TenantId, ct);
        Categories = await catalog.CategoriesAsync(TenantId, ct);
        if (!IsNew && CanSeePrice) CustomerPrices = await catalog.CustomerPricesAsync(TenantId, Id!.Value, ct);
        Existing ??= IsNew ? null : await catalog.GetAsync(TenantId, Id!.Value, ct);
    }

    private static ItemForm FromOffering(Offering o) => new()
    {
        OfferingType = o.OfferingType, OfferingName = o.OfferingName, OfferingCode = o.OfferingCode, Description = o.Description,
        CategoryId = o.CategoryId, BrandName = o.BrandName, UnitId = o.UnitId, TaxRateId = o.TaxRateId, HsnSacCode = o.HsnSacCode,
        DefaultPrice = Tidy(o.DefaultPrice), DefaultCost = Tidy(o.DefaultCost), IsPriceInclusive = o.IsPriceInclusive, IsPureAgent = o.IsPureAgent,
        IsRecurring = o.IsRecurring, IsSellable = o.IsSellable, IsPurchasable = o.IsPurchasable,
        Barcode = o.Barcode, PackSize = o.PackSize, TracksStock = o.TracksStock ?? false, ReorderLevel = Tidy(o.ReorderLevel),
    };

    /// <summary>Stored to 4 places; shown as typed: 4500.0000 → 4500, 12.5000 → 12.5.</summary>
    private static decimal? Tidy(decimal? d) => d is null ? null : d.Value / 1.0000000000000000000000000000m;

    private static string? Blank(string? s) => string.IsNullOrWhiteSpace(s) ? null : s.Trim();
}
