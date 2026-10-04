namespace BillingMadeEasy.Core.Parties;

/// <summary>
/// Labels for the codes stored in tbl_Parties / tbl_PartyAddresses. The numbers are fixed by
/// the database constraints; the wording lives only here so it can be corrected in one place.
/// </summary>
public static class PartyCodes
{
    public const byte RoleCustomer = 1;
    public const byte RoleSupplier = 2;

    public const byte StatusActive = 1;
    public const byte StatusOnHold = 2;
    public const byte StatusClosed = 3;

    public const byte AddressBilling = 2;

    /// <summary>tbl_Parties.PartyType, 1–7 (CK_Parties_Type). 2 is a company: existing data stores Pvt Ltd firms as 2.</summary>
    public static readonly IReadOnlyList<(byte Code, string Label)> PartyTypes =
    [
        (1, "Individual / proprietor"),
        (2, "Company"),
        (3, "Partnership"),
        (4, "LLP"),
        (5, "Trust / society"),
        (6, "Government"),
        (7, "Other"),
    ];

    /// <summary>tbl_PartyAddresses.AddressType, 1–4 (CK_PartyAddr_Type). 2 is billing: locations create type-2 addresses.</summary>
    public static readonly IReadOnlyList<(byte Code, string Label)> AddressTypes =
    [
        (1, "Registered office"),
        (2, "Billing"),
        (3, "Shipping"),
        (4, "Other"),
    ];

    public static string PartyType(byte code) => PartyTypes.FirstOrDefault(t => t.Code == code).Label ?? "Other";

    public static string AddressType(byte code) => AddressTypes.FirstOrDefault(t => t.Code == code).Label ?? "Other";

    public static string Status(byte code) => code switch
    {
        StatusActive => "Active",
        StatusOnHold => "On hold",
        StatusClosed => "Closed",
        _ => "Unknown",
    };
}
