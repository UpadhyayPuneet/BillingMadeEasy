using System.ComponentModel.DataAnnotations;
using System.Text.Json;
using BillingMadeEasy.Core.Parties;
using BillingMadeEasy.Core.Tax;
using BillingMadeEasy.Web.Features.Parties;
using BillingMadeEasy.Web.Infrastructure.Pages;
using Microsoft.AspNetCore.Mvc;

namespace BillingMadeEasy.Web.Pages.Parties;

public sealed class ViewModel(PartyStore parties) : TenantPageModel
{
    public sealed class LocationInput
    {
        public long PartyLocationId { get; set; }
        [Required(ErrorMessage = "Give the branch a name."), StringLength(100)] public string LocationName { get; set; } = "";
        [StringLength(30)] public string? LocationCode { get; set; }
        public string? Gstin { get; set; }
        [StringLength(20)] public string? Phone { get; set; }
        [EmailAddress(ErrorMessage = "That email address doesn't look right."), StringLength(150)] public string? Email { get; set; }
        public bool IsDefault { get; set; }
        [StringLength(150)] public string? AddressLine1 { get; set; }
        [StringLength(150)] public string? AddressLine2 { get; set; }
        [StringLength(80)] public string? City { get; set; }
        public string? StateCode { get; set; }
        [StringLength(15)] public string? PostalCode { get; set; }
    }

    public sealed class AddressInput
    {
        public long PartyAddressId { get; set; }
        public byte AddressType { get; set; } = PartyCodes.AddressBilling;
        [StringLength(60)] public string? AddressLabel { get; set; }
        [Required(ErrorMessage = "Enter the first line of the address."), StringLength(150)] public string Line1 { get; set; } = "";
        [StringLength(150)] public string? Line2 { get; set; }
        [StringLength(80)] public string? City { get; set; }
        public string? StateCode { get; set; }
        [StringLength(15)] public string? PostalCode { get; set; }
        public bool IsDefault { get; set; }
    }

    public sealed class ContactInput
    {
        public long PartyContactId { get; set; }
        public long? PartyLocationId { get; set; }
        [Required(ErrorMessage = "Enter the contact's name."), StringLength(120)] public string ContactName { get; set; } = "";
        [StringLength(80)] public string? Designation { get; set; }
        [StringLength(80)] public string? Department { get; set; }
        [StringLength(20)] public string? Phone { get; set; }
        [StringLength(20)] public string? Mobile { get; set; }
        [EmailAddress(ErrorMessage = "That email address doesn't look right."), StringLength(150)] public string? Email { get; set; }
        [StringLength(300)] public string? Notes { get; set; }
        public bool IsPrimary { get; set; }
    }

    public sealed class BrandInput
    {
        public long PartyBrandId { get; set; }
        [Required(ErrorMessage = "Enter the brand name."), StringLength(100)] public string BrandName { get; set; } = "";
        [StringLength(30)] public string? BrandCode { get; set; }
        [StringLength(300)] public string? Description { get; set; }
    }

    [BindProperty(SupportsGet = true)]
    public long Id { get; set; }

    public PartyDetail Detail { get; private set; } = null!;

    public IReadOnlyList<StateOption> States { get; private set; } = [];

    public IReadOnlyList<PossibleDuplicate> Duplicates { get; private set; } = [];

    /// <summary>When a dialog's save failed, which one to reopen, and with what the person typed.</summary>
    public string? OpenDialog { get; private set; }
    public LocationInput Location { get; private set; } = new();
    public AddressInput Address { get; private set; } = new();
    public ContactInput Contact { get; private set; } = new();
    public BrandInput Brand { get; private set; } = new();

    public bool CanEditParty => Can("Party.Customer.Manage") || Can("Party.Supplier.Manage");
    public bool CanLocations => Can("Party.Location.Manage");
    public bool CanContacts => Can("Party.Contact.Manage");
    public bool CanBrands => Can("Party.Brand.Manage");

    public async Task<IActionResult> OnGetAsync(CancellationToken ct)
    {
        if (TempData["PartyDuplicates"] is string json)
            Duplicates = JsonSerializer.Deserialize<List<PossibleDuplicate>>(json) ?? [];
        return await LoadAsync(ct) ? Page() : NotFound();
    }

    public async Task<IActionResult> OnPostLocationAsync([FromForm(Name = "Location")] LocationInput input, CancellationToken ct)
    {
        if (!CanLocations) return Forbid();
        input.Gstin = string.IsNullOrWhiteSpace(input.Gstin) ? null : Gstin.Normalize(input.Gstin);
        if (input.Gstin is not null)
        {
            var check = Gstin.Check(input.Gstin);
            if (check != GstinCheck.Valid)
                ModelState.AddModelError("Location.Gstin", "That isn't a valid GSTIN. Check each character.");
            else if (input.StateCode is null)
                input.StateCode = Gstin.StateCode(input.Gstin);
            else if (input.StateCode != Gstin.StateCode(input.Gstin))
                ModelState.AddModelError("Location.StateCode",
                    $"The GSTIN is registered in {StateCodes.Name(Gstin.StateCode(input.Gstin))} but the address is in {StateCodes.Name(input.StateCode)}.");
        }
        if (!ModelState.IsValid) return await ReopenAsync("location", () => Location = input, ct);

        var result = await parties.SaveLocationAsync(new
        {
            TenantId, PartyId = Id, input.PartyLocationId, input.LocationName, LocationCode = Blank(input.LocationCode),
            input.Gstin, Phone = Blank(input.Phone), Email = Blank(input.Email), input.IsDefault,
            AddressLine1 = Blank(input.AddressLine1), AddressLine2 = Blank(input.AddressLine2), City = Blank(input.City),
            StateCode = Blank(input.StateCode), PostalCode = Blank(input.PostalCode), CountryCode = "IN",
            ActionByUserId = UserId, IpAddress,
        }, ct);
        return await FinishAsync(result, "location", "Branch saved.", () => Location = input, ct);
    }

    public async Task<IActionResult> OnPostAddressAsync([FromForm(Name = "Address")] AddressInput input, CancellationToken ct)
    {
        if (!CanLocations) return Forbid();
        if (!ModelState.IsValid) return await ReopenAsync("address", () => Address = input, ct);

        var result = await parties.SaveAddressAsync(new
        {
            TenantId, PartyId = Id, input.PartyAddressId, input.AddressType, AddressLabel = Blank(input.AddressLabel),
            input.Line1, Line2 = Blank(input.Line2), City = Blank(input.City), StateCode = Blank(input.StateCode),
            PostalCode = Blank(input.PostalCode), CountryCode = "IN", input.IsDefault, ActionByUserId = UserId, IpAddress,
        }, ct);
        return await FinishAsync(result, "address", "Address saved.", () => Address = input, ct);
    }

    public async Task<IActionResult> OnPostContactAsync([FromForm(Name = "Contact")] ContactInput input, CancellationToken ct)
    {
        if (!CanContacts) return Forbid();
        if (!ModelState.IsValid) return await ReopenAsync("contact", () => Contact = input, ct);

        var result = await parties.SaveContactAsync(new
        {
            TenantId, PartyId = Id, input.PartyContactId, input.PartyLocationId, input.ContactName,
            Designation = Blank(input.Designation), Department = Blank(input.Department), Phone = Blank(input.Phone),
            Mobile = Blank(input.Mobile), Email = Blank(input.Email), Notes = Blank(input.Notes), input.IsPrimary,
            ActionByUserId = UserId, IpAddress,
        }, ct);
        return await FinishAsync(result, "contact", "Contact saved.", () => Contact = input, ct);
    }

    public async Task<IActionResult> OnPostBrandAsync([FromForm(Name = "Brand")] BrandInput input, CancellationToken ct)
    {
        if (!CanBrands) return Forbid();
        if (!ModelState.IsValid) return await ReopenAsync("brand", () => Brand = input, ct);

        var result = await parties.SaveBrandAsync(new
        {
            TenantId, PartyId = Id, input.PartyBrandId, input.BrandName, BrandCode = Blank(input.BrandCode),
            Description = Blank(input.Description), ColorPalette = (string?)null, ActionByUserId = UserId, IpAddress,
        }, ct);
        return await FinishAsync(result, "brand", "Brand saved.", () => Brand = input, ct);
    }

    public async Task<IActionResult> OnPostDeleteAsync(string kind, long itemId, CancellationToken ct)
    {
        bool allowed = kind switch
        {
            "location" or "address" => CanLocations,
            "contact" => CanContacts,
            "brand" => CanBrands,
            _ => false,
        };
        if (!allowed) return Forbid();

        var result = await parties.DeleteAsync(kind, TenantId, Id, itemId, UserId, IpAddress, ct);
        Flash = result.Succeeded ? "Removed." : result.ResultMessage;
        return RedirectToPage(new { id = Id });
    }

    public async Task<IActionResult> OnPostStatusAsync(byte? status, bool? isActive, string? reason, CancellationToken ct)
    {
        if (!CanEditParty) return Forbid();
        if (status is not null and not (PartyCodes.StatusActive or PartyCodes.StatusOnHold or PartyCodes.StatusClosed)) return BadRequest();

        var result = await parties.SetStatusAsync(TenantId, Id, status, isActive, string.IsNullOrWhiteSpace(reason) ? null : reason.Trim(), UserId, IpAddress, ct);
        Flash = !result.Succeeded ? result.ResultMessage
            : isActive == false ? "Archived. It no longer appears in pickers; history is kept."
            : isActive == true ? "Restored."
            : status == PartyCodes.StatusActive ? "Active again. Sales and purchases are allowed."
            : status == PartyCodes.StatusOnHold ? "On hold. New sales and purchases are blocked until it's made active."
            : "Closed. Kept in reports; no new business.";
        return RedirectToPage(new { id = Id });
    }

    private async Task<IActionResult> FinishAsync(SaveResult result, string kind, string message, Action keep, CancellationToken ct)
    {
        if (result.Succeeded)
        {
            Flash = message;
            return RedirectToPage(new { id = Id });
        }
        string field = string.IsNullOrEmpty(result.FieldName) ? "" : $"{char.ToUpperInvariant(kind[0])}{kind[1..]}.{result.FieldName}";
        ModelState.AddModelError(field, result.ResultMessage ?? "That couldn't be saved.");
        return await ReopenAsync(kind, keep, ct);
    }

    private async Task<IActionResult> ReopenAsync(string kind, Action keep, CancellationToken ct)
    {
        keep();
        OpenDialog = kind;
        return await LoadAsync(ct) ? Page() : NotFound();
    }

    private async Task<bool> LoadAsync(CancellationToken ct)
    {
        var detail = await parties.GetAsync(TenantId, Id, ct);
        if (detail is null) return false;
        Detail = detail;
        States = await parties.StatesAsync(ct);
        return true;
    }

    private static string? Blank(string? s) => string.IsNullOrWhiteSpace(s) ? null : s.Trim();
}
