using System.Globalization;
using System.Text.Json;
using BillingMadeEasy.Web.Features.Business;
using QRCoder;

namespace BillingMadeEasy.Web.Features.Sales;

public sealed record SellerBank(string BankName, string AccountName, string AccountNumber, string Ifsc, string? BranchName, string? UpiId);

/// <summary>
/// Who the invoice is from, as printed. A draft reads it live from the profile; issuing freezes a
/// copy onto the invoice, so a new address or logo next year never changes an invoice already sent.
/// </summary>
public sealed record Seller(
    string Name, string LegalName, string? Gstin, string? Pan, string? StateCode, string? StateName,
    IReadOnlyList<string> Address, string? Phone, string? Email, string? Website,
    string? LogoPath, string? SignaturePath, string? SignatoryName, string? SignatoryTitle, string? AccentColor,
    string? UdyamNumber, string? Cin, string? LutNumber, bool IsComposition, SellerBank? Bank)
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    public static Seller From(BusinessProfile p, IReadOnlyList<BankAccount> accounts)
    {
        var bank = accounts.FirstOrDefault(a => a.IsDefault) ?? accounts.FirstOrDefault();
        return new Seller(p.ProfileName, p.LegalName, p.Gstin, p.Pan, p.StateCode, p.StateName,
            p.AddressLines().ToList(), p.Phone, p.Email, p.Website, p.LogoPath, p.SignaturePath, p.SignatoryName, p.SignatoryTitle,
            p.AccentColor, p.UdyamNumber, p.Cin, p.LutNumber, p.IsComposition,
            bank is null ? null : new SellerBank(bank.BankName, bank.AccountName, bank.AccountNumber, bank.Ifsc, bank.BranchName, bank.UpiId));
    }

    public string ToJson() => JsonSerializer.Serialize(this, Json);

    public static Seller? FromJson(string? json) => string.IsNullOrWhiteSpace(json) ? null : JsonSerializer.Deserialize<Seller>(json, Json);
}

/// <summary>A UPI payment QR: any UPI app scans it and fills in the payee, amount and reference.</summary>
public static class UpiQr
{
    public static string Link(string upiId, string payeeName, decimal amount, string? reference)
    {
        string Q(string s) => Uri.EscapeDataString(s);
        var link = $"upi://pay?pa={Q(upiId)}&pn={Q(payeeName)}&am={amount.ToString("0.00", CultureInfo.InvariantCulture)}&cu=INR";
        if (!string.IsNullOrWhiteSpace(reference)) link += "&tn=" + Q(reference);
        return link;
    }

    /// <summary>The QR as a PNG data URI, for an &lt;img&gt; (allowed by the CSP, unlike inline SVG styles).</summary>
    public static string DataUri(string link)
    {
        using var generator = new QRCodeGenerator();
        using var data = generator.CreateQrCode(link, QRCodeGenerator.ECCLevel.M);
        byte[] png = new PngByteQRCode(data).GetGraphic(6);
        return "data:image/png;base64," + Convert.ToBase64String(png);
    }
}
