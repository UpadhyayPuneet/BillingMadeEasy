using System.ComponentModel.DataAnnotations;
using BillingMadeEasy.Core.Design;
using BillingMadeEasy.Web.Features.Parties;
using BillingMadeEasy.Web.Infrastructure.Files;
using BillingMadeEasy.Web.Infrastructure.Pages;
using Microsoft.AspNetCore.Mvc;

namespace BillingMadeEasy.Web.Pages.Parties;

/// <summary>
/// A client's brand kit: what a designer, editor or copywriter needs to produce work that is right
/// the first time — logo files, exact colours, fonts, voice, channels, and the client's rules.
/// </summary>
public sealed class BrandModel(PartyStore parties, FileStore files) : TenantPageModel
{
    public sealed class KitForm
    {
        public List<ColorInput> Colors { get; set; } = [];
        [StringLength(80)] public string? FontHeading { get; set; }
        [StringLength(80)] public string? FontBody { get; set; }
        [StringLength(200)] public string? Tagline { get; set; }
        [StringLength(200)] public string? Website { get; set; }
        [StringLength(100)] public string? Instagram { get; set; }
        [StringLength(100)] public string? Facebook { get; set; }
        [StringLength(100)] public string? LinkedIn { get; set; }
        [StringLength(100)] public string? YouTube { get; set; }
        [StringLength(2000)] public string? Guidelines { get; set; }
    }

    public sealed class ColorInput
    {
        [StringLength(40)] public string? Name { get; set; }
        public string? Hex { get; set; }
    }

    [BindProperty(SupportsGet = true)] public long PartyId { get; set; }
    [BindProperty(SupportsGet = true)] public long BrandId { get; set; }

    [BindProperty] public KitForm Form { get; set; } = new();

    public BrandKit Kit { get; private set; } = null!;
    public IReadOnlyList<BrandColor> Colors { get; private set; } = [];
    public bool CanEdit => Can("Party.Brand.Manage");
    public bool Editing { get; private set; }

    public async Task<IActionResult> OnGetAsync(CancellationToken ct)
    {
        if (!await LoadAsync(ct)) return NotFound();
        Form = new KitForm
        {
            Colors = Colors.Select(c => new ColorInput { Name = c.Name, Hex = c.Hex }).ToList(),
            FontHeading = Kit.FontHeading, FontBody = Kit.FontBody, Tagline = Kit.Tagline, Website = Kit.Website,
            Instagram = Kit.Instagram, Facebook = Kit.Facebook, LinkedIn = Kit.LinkedIn, YouTube = Kit.YouTube,
            Guidelines = Kit.Guidelines,
        };
        return Page();
    }

    public async Task<IActionResult> OnPostKitAsync(CancellationToken ct)
    {
        if (!CanEdit) return Forbid();
        if (!await LoadAsync(ct)) return NotFound();

        var colors = new List<BrandColor>();
        for (int i = 0; i < Form.Colors.Count; i++)
        {
            var c = Form.Colors[i];
            if (string.IsNullOrWhiteSpace(c.Hex) && string.IsNullOrWhiteSpace(c.Name)) continue;
            if (BrandColor.NormalizeHex(c.Hex) is not { } hex)
            {
                ModelState.AddModelError($"Form.Colors[{i}].Hex", $"“{c.Hex}” isn't a colour code. Use the form #E63946.");
                continue;
            }
            colors.Add(new BrandColor(string.IsNullOrWhiteSpace(c.Name) ? $"Colour {colors.Count + 1}" : c.Name.Trim(), hex));
        }
        if (colors.Count > 12) ModelState.AddModelError("", "Keep it to 12 colours; a brand book rarely needs more.");
        if (!ModelState.IsValid)
        {
            Editing = true;
            return Page();
        }

        var result = await parties.SaveKitAsync(new
        {
            TenantId, PartyId, PartyBrandId = BrandId,
            ColorPalette = BrandColor.Serialize(colors),
            FontHeading = Blank(Form.FontHeading), FontBody = Blank(Form.FontBody), Tagline = Blank(Form.Tagline),
            Website = Blank(Form.Website), Instagram = Handle(Form.Instagram), Facebook = Handle(Form.Facebook),
            LinkedIn = Blank(Form.LinkedIn), YouTube = Handle(Form.YouTube), Guidelines = Blank(Form.Guidelines),
            ActionByUserId = UserId, IpAddress,
        }, ct);
        if (!result.Succeeded)
        {
            ModelState.AddModelError("", result.ResultMessage + ".");
            Editing = true;
            return Page();
        }
        Flash = "Brand kit saved.";
        return RedirectToPage(new { PartyId, BrandId });
    }

    public async Task<IActionResult> OnPostLogoAsync(byte variant, IFormFile? file, CancellationToken ct)
    {
        if (!CanEdit) return Forbid();
        if (variant is not (1 or 2)) return BadRequest();
        if (file is null)
        {
            Flash = "Choose an image first.";
            return RedirectToPage(new { PartyId, BrandId });
        }

        var check = await FileStore.CheckImageAsync(file, ct);
        if (!check.Ok)
        {
            Flash = check.Problem;
            return RedirectToPage(new { PartyId, BrandId });
        }

        string path = await files.SaveAsync(TenantId, "brands", file, check.Extension!, ct);
        var result = await parties.SetLogoAsync(TenantId, PartyId, BrandId, variant, path, UserId, IpAddress, ct);
        if (!result.Succeeded)
        {
            files.Delete(path);
            return NotFound();
        }
        files.Delete(result.OldPath);
        Flash = variant == 1 ? "Logo updated." : "Logo for dark backgrounds updated.";
        return RedirectToPage(new { PartyId, BrandId });
    }

    public async Task<IActionResult> OnPostRemoveLogoAsync(byte variant, CancellationToken ct)
    {
        if (!CanEdit) return Forbid();
        var result = await parties.SetLogoAsync(TenantId, PartyId, BrandId, variant, null, UserId, IpAddress, ct);
        if (!result.Succeeded) return NotFound();
        files.Delete(result.OldPath);
        Flash = "Logo removed.";
        return RedirectToPage(new { PartyId, BrandId });
    }

    /// <summary>A social handle or URL as people paste it, as a full link.</summary>
    public static string? SocialUrl(string? value, string site) => string.IsNullOrWhiteSpace(value) ? null
        : value.StartsWith("http", StringComparison.OrdinalIgnoreCase) ? value
        : $"https://{site}/{value.TrimStart('@')}";

    public static string? WebUrl(string? value) => string.IsNullOrWhiteSpace(value) ? null
        : value.StartsWith("http", StringComparison.OrdinalIgnoreCase) ? value : "https://" + value;

    private async Task<bool> LoadAsync(CancellationToken ct)
    {
        var kit = await parties.GetKitAsync(TenantId, PartyId, BrandId, ct);
        if (kit is null) return false;
        Kit = kit;
        Colors = BrandColor.Parse(kit.ColorPalette);
        return true;
    }

    private static string? Blank(string? s) => string.IsNullOrWhiteSpace(s) ? null : s.Trim();

    /// <summary>"https://instagram.com/freshbite/" and "@freshbite" are kept as typed, minus stray spaces.</summary>
    private static string? Handle(string? s) => Blank(s)?.TrimEnd('/');
}
