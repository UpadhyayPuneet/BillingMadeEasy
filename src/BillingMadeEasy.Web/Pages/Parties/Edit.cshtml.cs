using System.ComponentModel.DataAnnotations;
using System.Text.Json;
using System.Text.RegularExpressions;
using BillingMadeEasy.Core.Parties;
using BillingMadeEasy.Core.Tax;
using BillingMadeEasy.Web.Features.Parties;
using BillingMadeEasy.Web.Infrastructure.Pages;
using Microsoft.AspNetCore.Mvc;

namespace BillingMadeEasy.Web.Pages.Parties;

public sealed partial class EditModel(PartyStore parties) : TenantPageModel
{
    public sealed class PartyForm
    {
        public byte PartyType { get; set; } = 2;

        [Required(ErrorMessage = "Enter the name."), StringLength(200, MinimumLength = 2, ErrorMessage = "Enter the name.")]
        public string LegalName { get; set; } = "";

        [StringLength(150)]
        public string? DisplayName { get; set; }

        [StringLength(200)]
        public string? TradingName { get; set; }

        [StringLength(30)]
        public string? PartyCode { get; set; }

        [StringLength(10)]
        public string? TaxIdNumber { get; set; }

        public long? CategoryId { get; set; }

        [EmailAddress(ErrorMessage = "That email address doesn't look right."), StringLength(150)]
        public string? Email { get; set; }

        [StringLength(20)]
        public string? Phone { get; set; }

        [StringLength(200)]
        public string? Website { get; set; }

        [StringLength(1000)]
        public string? Notes { get; set; }

        public bool IsCustomer { get; set; }

        [Range(0, 3650, ErrorMessage = "Between 0 and 3650 days.")]
        public int? CustomerTermDays { get; set; }

        [Range(0, 999_999_999_999, ErrorMessage = "Enter a positive amount.")]
        public decimal? CustomerCreditLimit { get; set; }

        public decimal CustomerOpening { get; set; }

        public bool IsSupplier { get; set; }

        [Range(0, 3650, ErrorMessage = "Between 0 and 3650 days.")]
        public int? SupplierTermDays { get; set; }

        public decimal SupplierOpening { get; set; }

        // First branch, only when adding a new party.
        public string? Gstin { get; set; }

        [StringLength(150)]
        public string? AddressLine1 { get; set; }

        [StringLength(80)]
        public string? City { get; set; }

        [StringLength(15)]
        public string? PostalCode { get; set; }

        public string? StateCode { get; set; }
    }

    [BindProperty(SupportsGet = true)]
    public long? Id { get; set; }

    [BindProperty]
    public PartyForm Form { get; set; } = new();

    public bool IsNew => Id is null or 0;

    /// <summary>Set when the GSTIN typed for a new party is already on file.</summary>
    public GstinOwner? ExistingOwner { get; private set; }

    public IReadOnlyList<Lookup> Categories { get; private set; } = [];

    public IReadOnlyList<StateOption> States { get; private set; } = [];

    public bool CanCustomer => Can("Party.Customer.Manage");

    public bool CanSupplier => Can("Party.Supplier.Manage");

    [GeneratedRegex("^[A-Z]{5}[0-9]{4}[A-Z]$")]
    private static partial Regex PanPattern();

    public async Task<IActionResult> OnGetAsync(string? role, string? name, CancellationToken ct)
    {
        if (!IsNew)
        {
            var detail = await parties.GetAsync(TenantId, Id!.Value, ct);
            if (detail is null) return NotFound();
            Form = FromDetail(detail);
        }
        else
        {
            Form.IsCustomer = role != "supplier" && CanCustomer;
            Form.IsSupplier = role == "supplier" && CanSupplier;
            Form.LegalName = name?.Trim() ?? "";
        }

        await LoadLookupsAsync(ct);
        return Page();
    }

    /// <summary>Live check while typing: who already has this GSTIN?</summary>
    public async Task<IActionResult> OnGetGstinOwnerAsync(string gstin, CancellationToken ct)
    {
        string normalized = Gstin.Normalize(gstin);
        if (!Gstin.IsValid(normalized)) return new JsonResult(null);
        var owner = await parties.FindByGstinAsync(TenantId, normalized, ct);
        return new JsonResult(owner is null ? null : new { id = owner.PartyId, name = owner.DisplayName, url = $"/Parties/View/{owner.PartyId}" });
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken ct)
    {
        Normalize(Form);

        PartyDetail? existing = null;
        if (!IsNew)
        {
            existing = await parties.GetAsync(TenantId, Id!.Value, ct);
            if (existing is null) return NotFound();
            KeepRolesTheUserCannotManage(existing);
        }

        Validate();
        if (IsNew && Form.Gstin is not null && ModelState.IsValid
            && await parties.FindByGstinAsync(TenantId, Form.Gstin, ct) is { } owner)
        {
            ExistingOwner = owner;
            ModelState.AddModelError("Form.Gstin", $"This GSTIN already belongs to {owner.DisplayName}.");
        }
        if (!ModelState.IsValid)
        {
            await LoadLookupsAsync(ct);
            return Page();
        }

        var (result, duplicates) = await parties.SaveAsync(new
        {
            TenantId,
            PartyId = Id ?? 0,
            Form.PartyType,
            Form.LegalName,
            Form.TradingName,
            Form.DisplayName,
            Form.PartyCode,
            Form.TaxIdNumber,
            Form.CategoryId,
            Form.Email,
            Form.Phone,
            Form.Website,
            Form.Notes,
            Form.IsCustomer,
            Form.CustomerTermDays,
            Form.CustomerCreditLimit,
            Form.CustomerOpening,
            Form.IsSupplier,
            Form.SupplierTermDays,
            Form.SupplierOpening,
            ActionByUserId = UserId,
            IpAddress,
        }, ct);

        if (!result.Succeeded)
        {
            ModelState.AddModelError(FieldKey(result.FieldName), result.ResultMessage ?? "That couldn't be saved.");
            await LoadLookupsAsync(ct);
            return Page();
        }

        string message = result.IsNew ? $"Added {DisplayOf(Form)}." : "Saved.";

        if (result.IsNew && Form.Gstin is not null)
        {
            var branch = await parties.SaveLocationAsync(new
            {
                TenantId,
                PartyId = result.PartyId,
                PartyLocationId = 0L,
                LocationName = Form.City ?? "Main branch",
                Gstin = Form.Gstin,
                IsDefault = true,
                AddressLine1 = Form.AddressLine1,
                City = Form.City,
                StateCode = Form.StateCode,
                PostalCode = Form.PostalCode,
                CountryCode = "IN",
                ActionByUserId = UserId,
                IpAddress,
            }, ct);

            message = branch.Succeeded
                ? $"Added {DisplayOf(Form)} with its GST branch."
                : $"Added {DisplayOf(Form)}, but the branch wasn't saved: {branch.ResultMessage}. Add it below.";
        }

        Flash = message;
        if (duplicates.Count > 0) TempData["PartyDuplicates"] = JsonSerializer.Serialize(duplicates);
        return RedirectToPage("/Parties/View", new { id = result.PartyId });
    }

    private void Validate()
    {
        if (!Form.IsCustomer && !Form.IsSupplier)
            ModelState.AddModelError("Form.IsCustomer", "Mark them as a customer, a supplier, or both.");
        if (Form.IsCustomer && !CanCustomer && IsNew)
            ModelState.AddModelError("Form.IsCustomer", "You can't add customers.");
        if (Form.IsSupplier && !CanSupplier && IsNew)
            ModelState.AddModelError("Form.IsSupplier", "You can't add suppliers.");

        if (Form.TaxIdNumber is not null && !PanPattern().IsMatch(Form.TaxIdNumber))
            ModelState.AddModelError("Form.TaxIdNumber", "A PAN is 10 characters: 5 letters, 4 digits, 1 letter.");

        if (IsNew && Form.Gstin is not null)
        {
            var check = Gstin.Check(Form.Gstin);
            if (check != GstinCheck.Valid)
                ModelState.AddModelError("Form.Gstin", check switch
                {
                    GstinCheck.WrongLength => "A GSTIN is 15 characters.",
                    GstinCheck.UnknownState => "The first two digits aren't a GST state code.",
                    GstinCheck.ChecksumMismatch => "The last character doesn't match. One character is probably mistyped.",
                    _ => "That isn't a valid GSTIN.",
                });
            else if (Form.TaxIdNumber is not null && Form.TaxIdNumber != Gstin.Pan(Form.Gstin))
                ModelState.AddModelError("Form.TaxIdNumber", $"The GSTIN belongs to PAN {Gstin.Pan(Form.Gstin)}.");
        }
    }

    /// <summary>Someone allowed to manage suppliers but not customers must not be able to change customer terms.</summary>
    private void KeepRolesTheUserCannotManage(PartyDetail existing)
    {
        if (!CanCustomer)
        {
            Form.IsCustomer = existing.Customer is not null;
            Form.CustomerTermDays = existing.Customer?.PaymentTermDays;
            Form.CustomerCreditLimit = existing.Customer?.CreditLimit;
            Form.CustomerOpening = existing.Customer?.OpeningBalance ?? 0;
        }
        if (!CanSupplier)
        {
            Form.IsSupplier = existing.Supplier is not null;
            Form.SupplierTermDays = existing.Supplier?.PaymentTermDays;
            Form.SupplierOpening = existing.Supplier?.OpeningBalance ?? 0;
        }
    }

    private static void Normalize(PartyForm f)
    {
        static string? Clean(string? s) => string.IsNullOrWhiteSpace(s) ? null : s.Trim();
        f.LegalName = f.LegalName?.Trim() ?? "";
        f.DisplayName = Clean(f.DisplayName);
        f.TradingName = Clean(f.TradingName);
        f.PartyCode = Clean(f.PartyCode);
        f.TaxIdNumber = Clean(f.TaxIdNumber)?.ToUpperInvariant().Replace(" ", "");
        f.Email = Clean(f.Email);
        f.Phone = Clean(f.Phone);
        f.Website = Clean(f.Website);
        f.Notes = Clean(f.Notes);
        f.Gstin = Clean(f.Gstin) is { } g ? Gstin.Normalize(g) : null;
        f.AddressLine1 = Clean(f.AddressLine1);
        f.City = Clean(f.City);
        f.PostalCode = Clean(f.PostalCode);
        f.StateCode = Clean(f.StateCode);

        // A valid GSTIN is the source of truth for PAN and state.
        if (f.Gstin is not null && Gstin.IsValid(f.Gstin))
        {
            f.TaxIdNumber ??= Gstin.Pan(f.Gstin);
            f.StateCode = Gstin.StateCode(f.Gstin);
        }
        if (!f.IsCustomer) { f.CustomerTermDays = null; f.CustomerCreditLimit = null; f.CustomerOpening = 0; }
        if (!f.IsSupplier) { f.SupplierTermDays = null; f.SupplierOpening = 0; }
    }

    private static PartyForm FromDetail(PartyDetail d) => new()
    {
        PartyType = d.Party.PartyType,
        LegalName = d.Party.LegalName,
        DisplayName = string.Equals(d.Party.DisplayName, d.Party.LegalName, StringComparison.Ordinal) ? null : d.Party.DisplayName,
        TradingName = d.Party.TradingName,
        PartyCode = d.Party.PartyCode,
        TaxIdNumber = d.Party.TaxIdNumber,
        CategoryId = d.Party.CategoryId,
        Email = d.Party.Email,
        Phone = d.Party.Phone,
        Website = d.Party.Website,
        Notes = d.Party.Notes,
        IsCustomer = d.Customer is not null,
        CustomerTermDays = d.Customer?.PaymentTermDays,
        CustomerCreditLimit = d.Customer?.CreditLimit,
        CustomerOpening = d.Customer?.OpeningBalance ?? 0,
        IsSupplier = d.Supplier is not null,
        SupplierTermDays = d.Supplier?.PaymentTermDays,
        SupplierOpening = d.Supplier?.OpeningBalance ?? 0,
    };

    private async Task LoadLookupsAsync(CancellationToken ct)
    {
        Categories = await parties.CategoriesAsync(TenantId, ct);
        States = await parties.StatesAsync(ct);
    }

    private static string DisplayOf(PartyForm f) => f.DisplayName ?? f.LegalName;

    private static string FieldKey(string? field) => string.IsNullOrEmpty(field) ? string.Empty : "Form." + field;
}
