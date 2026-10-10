using System.ComponentModel.DataAnnotations;
using System.Text.RegularExpressions;
using BillingMadeEasy.Core.Billing;
using BillingMadeEasy.Core.Design;
using BillingMadeEasy.Core.Tax;
using BillingMadeEasy.Web.Features.Business;
using BillingMadeEasy.Web.Features.Parties;
using BillingMadeEasy.Web.Infrastructure.Files;
using BillingMadeEasy.Web.Infrastructure.Formatting;
using BillingMadeEasy.Web.Infrastructure.Pages;
using Microsoft.AspNetCore.Mvc;

namespace BillingMadeEasy.Web.Pages.Business;

public sealed partial class ProfileModel(BusinessStore business, PartyStore parties, FileStore files) : TenantPageModel
{
    public sealed class ProfileForm
    {
        [Required(ErrorMessage = "Enter the name customers know you by."), StringLength(150)] public string ProfileName { get; set; } = "";
        [Required(ErrorMessage = "Enter the legal name, as registered."), StringLength(200)] public string LegalName { get; set; } = "";
        public string? Gstin { get; set; }
        public string? Pan { get; set; }
        public string? StateCode { get; set; }
        [StringLength(150)] public string? AddressLine1 { get; set; }
        [StringLength(150)] public string? AddressLine2 { get; set; }
        [StringLength(80)] public string? City { get; set; }
        [RegularExpression(@"^\d{6}$", ErrorMessage = "A PIN code is 6 digits.")] public string? PostalCode { get; set; }
        [StringLength(20)] public string? Phone { get; set; }
        [EmailAddress(ErrorMessage = "That email address doesn't look right."), StringLength(150)] public string? Email { get; set; }
        [StringLength(200)] public string? Website { get; set; }
        [StringLength(120)] public string? SignatoryName { get; set; }
        [StringLength(80)] public string? SignatoryTitle { get; set; }
        public string? AccentColor { get; set; }
        public string? UdyamNumber { get; set; }
        public string? Cin { get; set; }
        public bool IsComposition { get; set; }
        [StringLength(30)] public string? LutNumber { get; set; }
        [StringLength(2000)] public string? InvoiceTerms { get; set; }
        [StringLength(500)] public string? InvoiceNote { get; set; }
        [Range(0, 365, ErrorMessage = "Between 0 and 365 days.")] public short? DefaultDueDays { get; set; }
        public bool RoundOffTotal { get; set; } = true;
        public bool IsDefault { get; set; }
    }

    public sealed class BankInput
    {
        public long BankAccountId { get; set; }
        [Required(ErrorMessage = "Enter the bank's name."), StringLength(100)] public string BankName { get; set; } = "";
        [Required(ErrorMessage = "Enter the name on the account."), StringLength(150)] public string AccountName { get; set; } = "";
        [Required(ErrorMessage = "Enter the account number.")] public string AccountNumber { get; set; } = "";
        [Required(ErrorMessage = "Enter the IFSC.")] public string Ifsc { get; set; } = "";
        [StringLength(100)] public string? BranchName { get; set; }
        public byte AccountType { get; set; } = BankAccountType.Current;
        public string? UpiId { get; set; }
        public bool IsDefault { get; set; }
    }

    public sealed class SeriesInput
    {
        public long SeriesId { get; set; }
        public byte DocumentType { get; set; } = DocumentTypes.TaxInvoice;
        [Required(ErrorMessage = "Give the series a name."), StringLength(60)] public string SeriesName { get; set; } = "";
        [StringLength(15)] public string? Prefix { get; set; }
        [StringLength(15)] public string? Suffix { get; set; }
        public string Separator { get; set; } = "-";
        [Range(1, 10, ErrorMessage = "Between 1 and 10 digits.")] public byte PadWidth { get; set; } = 4;
        public byte YearFormat { get; set; } = 2;
        public bool ResetYearly { get; set; } = true;
        [Range(1, int.MaxValue, ErrorMessage = "Start from 1 or more.")] public int StartFrom { get; set; } = 1;
        public bool IsDefault { get; set; }
    }

    [BindProperty(SupportsGet = true)] public long? Id { get; set; }
    public ProfileForm Form { get; private set; } = new();

    public BusinessProfile? Existing { get; private set; }
    public IReadOnlyList<BankAccount> Accounts { get; private set; } = [];
    public IReadOnlyList<SeriesRow> Series { get; private set; } = [];
    public IReadOnlyList<StateOption> States { get; private set; } = [];
    public string? OpenDialog { get; private set; }
    public BankInput Bank { get; private set; } = new();
    public SeriesInput SeriesForm { get; private set; } = new();

    public bool IsNew => Id is null or 0;
    public bool CanEdit => Can("Admin.Business.Manage");
    public bool CanNumbering => Can("Setup.Numbering.Manage");
    public int ThisYear => DocumentNumber.FinancialYear(DateOnly.FromDateTime(When.TodayIst()));

    public async Task<IActionResult> OnGetAsync(CancellationToken ct)
    {
        if (IsNew)
        {
            if (!CanEdit) return Forbid();
            Form.RoundOffTotal = true;
        }
        else
        {
            if (!await LoadAsync(ct)) return NotFound();
            Form = FromProfile(Existing!);
        }
        await LoadLookupsAsync(ct);
        return Page();
    }

    public async Task<IActionResult> OnPostAsync([FromForm(Name = "Form")] ProfileForm form, CancellationToken ct)
    {
        if (!CanEdit) return Forbid();
        Form = form;

        Form.Gstin = string.IsNullOrWhiteSpace(Form.Gstin) ? null : Gstin.Normalize(Form.Gstin);
        Form.Pan = string.IsNullOrWhiteSpace(Form.Pan) ? null : Form.Pan.Trim().ToUpperInvariant();
        Form.UdyamNumber = string.IsNullOrWhiteSpace(Form.UdyamNumber) ? null : Form.UdyamNumber.Trim().ToUpperInvariant();
        Form.Cin = string.IsNullOrWhiteSpace(Form.Cin) ? null : Form.Cin.Trim().ToUpperInvariant();
        string? accent = BrandColor.NormalizeHex(Form.AccentColor);

        if (Form.Gstin is not null && Gstin.Check(Form.Gstin) != GstinCheck.Valid)
            ModelState.AddModelError("Form.Gstin", "That isn't a valid GSTIN. Check each character.");
        if (Form.Pan is not null && !PanPattern().IsMatch(Form.Pan))
            ModelState.AddModelError("Form.Pan", "A PAN is 5 letters, 4 digits, 1 letter (e.g. ABCDE1234F).");
        if (Form.UdyamNumber is not null && !UdyamPattern().IsMatch(Form.UdyamNumber))
            ModelState.AddModelError("Form.UdyamNumber", "An Udyam number looks like UDYAM-MH-26-0012345.");
        if (Form.Cin is not null && !CinPattern().IsMatch(Form.Cin))
            ModelState.AddModelError("Form.Cin", "A CIN is 21 characters, e.g. U72200MH2020PTC123456.");
        if (!string.IsNullOrWhiteSpace(Form.AccentColor) && accent is null)
            ModelState.AddModelError("Form.AccentColor", "Use a colour code like #1D4ED8.");
        if (Form.IsComposition && Form.Gstin is null)
            ModelState.AddModelError("Form.IsComposition", "The composition scheme needs a GSTIN.");

        if (!ModelState.IsValid) return await RedisplayAsync(ct);

        var result = await business.SaveAsync(new
        {
            TenantId, BusinessProfileId = Id ?? 0, ProfileName = Form.ProfileName.Trim(), LegalName = Form.LegalName.Trim(),
            Form.Gstin, Form.Pan, StateCode = Blank(Form.StateCode),
            AddressLine1 = Blank(Form.AddressLine1), AddressLine2 = Blank(Form.AddressLine2), City = Blank(Form.City),
            PostalCode = Blank(Form.PostalCode), Phone = Blank(Form.Phone), Email = Blank(Form.Email),
            Website = Blank(Form.Website), SignatoryName = Blank(Form.SignatoryName), SignatoryTitle = Blank(Form.SignatoryTitle),
            AccentColor = accent, Form.UdyamNumber, Form.Cin, Form.IsComposition, LutNumber = Blank(Form.LutNumber),
            InvoiceTerms = Blank(Form.InvoiceTerms), InvoiceNote = Blank(Form.InvoiceNote), Form.DefaultDueDays,
            Form.RoundOffTotal, Form.IsDefault, ActionByUserId = UserId, IpAddress,
        }, ct);

        if (!result.Succeeded)
        {
            ModelState.AddModelError(result.FieldName is null ? "" : "Form." + result.FieldName, result.ResultMessage + ".");
            return await RedisplayAsync(ct);
        }

        Flash = result.IsNew ? $"Added {Form.ProfileName.Trim()}. It has its own invoice numbering; add a logo and bank account below." : "Saved. New invoices use these details; issued ones keep what they printed.";
        return RedirectToPage(new { id = result.BusinessProfileId });
    }

    public async Task<IActionResult> OnPostImageAsync(byte kind, IFormFile? file, CancellationToken ct)
    {
        if (!CanEdit || IsNew) return Forbid();
        if (kind is not (1 or 2)) return BadRequest();
        if (file is null) { Flash = "Choose an image first."; return RedirectToPage(new { id = Id }); }

        var check = await FileStore.CheckImageAsync(file, ct);
        if (!check.Ok) { Flash = check.Problem; return RedirectToPage(new { id = Id }); }

        string path = await files.SaveAsync(TenantId, "business", file, check.Extension!, ct);
        var result = await business.SetImageAsync(TenantId, Id!.Value, kind, path, UserId, IpAddress, ct);
        if (!result.Succeeded) { files.Delete(path); return NotFound(); }
        // The old image is kept: invoices already issued print the logo and signature they were issued with.
        Flash = kind == 1 ? "Logo updated. It prints at the top of every new invoice." : "Signature updated. It prints above the signatory's name.";
        return RedirectToPage(new { id = Id });
    }

    public async Task<IActionResult> OnPostRemoveImageAsync(byte kind, CancellationToken ct)
    {
        if (!CanEdit || IsNew) return Forbid();
        var result = await business.SetImageAsync(TenantId, Id!.Value, kind, null, UserId, IpAddress, ct);
        if (!result.Succeeded) return NotFound();
        // Kept on disk for invoices already issued with it.
        Flash = kind == 1 ? "Logo removed." : "Signature removed.";
        return RedirectToPage(new { id = Id });
    }

    public async Task<IActionResult> OnPostBankAsync([FromForm(Name = "Bank")] BankInput input, CancellationToken ct)
    {
        if (!CanEdit || IsNew) return Forbid();
        input.Ifsc = (input.Ifsc ?? "").Trim().ToUpperInvariant();
        input.AccountNumber = new string((input.AccountNumber ?? "").Where(char.IsDigit).ToArray());
        if (!ModelState.IsValid) return await ReopenAsync("bank", () => Bank = input, ct);

        var result = await business.SaveBankAccountAsync(new
        {
            TenantId, BusinessProfileId = Id, input.BankAccountId, BankName = input.BankName.Trim(), AccountName = input.AccountName.Trim(),
            input.AccountNumber, input.Ifsc, BranchName = Blank(input.BranchName), input.AccountType, UpiId = Blank(input.UpiId),
            input.IsDefault, ActionByUserId = UserId, IpAddress,
        }, ct);
        if (!result.Succeeded)
        {
            ModelState.AddModelError(result.FieldName is null ? "" : "Bank." + result.FieldName, result.ResultMessage + ".");
            return await ReopenAsync("bank", () => Bank = input, ct);
        }
        Flash = "Bank account saved. The default account prints on invoices.";
        return Redirect($"/Business/Profile/{Id}#payments");
    }

    public async Task<IActionResult> OnPostRemoveBankAsync(long accountId, CancellationToken ct)
    {
        if (!CanEdit || IsNew) return Forbid();
        var result = await business.RemoveBankAccountAsync(TenantId, Id!.Value, accountId, UserId, IpAddress, ct);
        Flash = result.Succeeded ? "Bank account removed. Invoices already sent still show it." : result.ResultMessage + ".";
        return Redirect($"/Business/Profile/{Id}#payments");
    }

    public async Task<IActionResult> OnPostSeriesAsync([FromForm(Name = "SeriesForm")] SeriesInput input, CancellationToken ct)
    {
        if (!CanNumbering || IsNew) return Forbid();
        if (input.YearFormat > 3) input.YearFormat = 0;
        if (!ModelState.IsValid) return await ReopenAsync("series", () => SeriesForm = input, ct);

        var result = await business.SaveSeriesAsync(new
        {
            TenantId, BusinessProfileId = Id, input.SeriesId, input.DocumentType, SeriesName = input.SeriesName.Trim(),
            Prefix = Blank(input.Prefix), Suffix = Blank(input.Suffix), Separator = input.Separator ?? "",
            input.PadWidth, input.YearFormat, input.ResetYearly, input.StartFrom, input.IsDefault,
            ActionByUserId = UserId, IpAddress,
        }, ct);
        if (!result.Succeeded)
        {
            ModelState.AddModelError(result.FieldName is null ? "" : "SeriesForm." + result.FieldName, result.ResultMessage + ".");
            return await ReopenAsync("series", () => SeriesForm = input, ct);
        }
        Flash = "Numbering saved.";
        return Redirect($"/Business/Profile/{Id}#numbering");
    }

    public async Task<IActionResult> OnPostRetireSeriesAsync(long seriesId, CancellationToken ct)
    {
        if (!CanNumbering || IsNew) return Forbid();
        var result = await business.RetireSeriesAsync(TenantId, Id!.Value, seriesId, UserId, IpAddress, ct);
        Flash = result.Succeeded ? "Series retired. Its numbers stay in the register." : result.ResultMessage + ".";
        return Redirect($"/Business/Profile/{Id}#numbering");
    }

    public async Task<IActionResult> OnPostActiveAsync(bool active, CancellationToken ct)
    {
        if (!CanEdit || IsNew) return Forbid();
        var result = await business.SetActiveAsync(TenantId, Id!.Value, active, UserId, IpAddress, ct);
        Flash = !result.Succeeded ? result.ResultMessage + "."
            : active ? "Restored. You can invoice under it again." : "Retired. Its invoices and numbers are kept.";
        return RedirectToPage(new { id = Id });
    }

    private async Task<IActionResult> RedisplayAsync(CancellationToken ct)
    {
        if (!IsNew && !await LoadAsync(ct)) return NotFound();
        await LoadLookupsAsync(ct);
        return Page();
    }

    private async Task<IActionResult> ReopenAsync(string dialog, Action keep, CancellationToken ct)
    {
        keep();
        OpenDialog = dialog;
        if (!await LoadAsync(ct)) return NotFound();
        Form = FromProfile(Existing!);
        await LoadLookupsAsync(ct);
        return Page();
    }

    private async Task<bool> LoadAsync(CancellationToken ct)
    {
        var (profile, accounts) = await business.GetAsync(TenantId, Id, ct);
        if (profile is null) return false;
        Existing = profile;
        Accounts = accounts;
        Series = await business.SeriesAsync(TenantId, profile.BusinessProfileId, ct);
        return true;
    }

    private async Task LoadLookupsAsync(CancellationToken ct) => States = await parties.StatesAsync(ct);

    private static ProfileForm FromProfile(BusinessProfile p) => new()
    {
        ProfileName = p.ProfileName, LegalName = p.LegalName, Gstin = p.Gstin, Pan = p.Pan, StateCode = p.StateCode,
        AddressLine1 = p.AddressLine1, AddressLine2 = p.AddressLine2, City = p.City, PostalCode = p.PostalCode,
        Phone = p.Phone, Email = p.Email, Website = p.Website, SignatoryName = p.SignatoryName, SignatoryTitle = p.SignatoryTitle,
        AccentColor = p.AccentColor, UdyamNumber = p.UdyamNumber, Cin = p.Cin, IsComposition = p.IsComposition,
        LutNumber = p.LutNumber, InvoiceTerms = p.InvoiceTerms, InvoiceNote = p.InvoiceNote, DefaultDueDays = p.DefaultDueDays,
        RoundOffTotal = p.RoundOffTotal, IsDefault = p.IsDefault,
    };

    private static string? Blank(string? s) => string.IsNullOrWhiteSpace(s) ? null : s.Trim();

    [GeneratedRegex("^[A-Z]{5}[0-9]{4}[A-Z]$")] private static partial Regex PanPattern();
    [GeneratedRegex(@"^UDYAM-[A-Z]{2}-\d{2}-\d{7}$")] private static partial Regex UdyamPattern();
    [GeneratedRegex("^[LU][0-9]{5}[A-Z]{2}[0-9]{4}[A-Z]{3}[0-9]{6}$")] private static partial Regex CinPattern();
}
