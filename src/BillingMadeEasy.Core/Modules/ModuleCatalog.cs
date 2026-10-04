namespace BillingMadeEasy.Core.Modules;

public static class ModuleKeys
{
    /// <summary>Sign-in, users, roles, settings, parties and catalog: every tenant has these.</summary>
    public const string Core = "core";
    public const string Billing = "billing";
    public const string Subscriptions = "subscriptions";
    public const string Inventory = "inventory";
    public const string Purchases = "purchases";
    public const string Accounting = "accounting";
    public const string Operations = "operations";
    public const string Hr = "hr";
    public const string Crm = "crm";
}

/// <param name="Requires">Hard dependencies: the module cannot function without these.</param>
/// <param name="Enhances">Soft links: when both are on, they integrate (an invoice moves stock,
/// a payment posts a journal). Neither side breaks when the other is off.</param>
public sealed record ModuleDescriptor(
    string Key,
    string Name,
    string Summary,
    string Icon,
    bool IsCore,
    bool IsAvailable,
    IReadOnlyList<string> Requires,
    IReadOnlyList<string> Enhances);

/// <summary>
/// The single list of modules. Each module is independent: it owns its pages, endpoints,
/// tables and permissions, and switching it on is one entitlement row — granted by a super admin,
/// bought as an add-on, or included in a plan.
/// </summary>
public static class ModuleCatalog
{
    public static IReadOnlyList<ModuleDescriptor> All { get; } =
    [
        new(ModuleKeys.Core, "Essentials", "Users, roles, customers, vendors, products and services, settings.", "apps",
            IsCore: true, IsAvailable: true, Requires: [], Enhances: []),
        new(ModuleKeys.Billing, "Billing", "Quotations, orders, GST invoices, credit notes, payments received.", "receipt_long",
            IsCore: false, IsAvailable: true, Requires: [], Enhances: [ModuleKeys.Inventory, ModuleKeys.Accounting]),
        new(ModuleKeys.Subscriptions, "Subscriptions", "Recurring plans, deliverables and automatic billing runs.", "autorenew",
            IsCore: false, IsAvailable: true, Requires: [ModuleKeys.Billing], Enhances: [ModuleKeys.Operations]),
        new(ModuleKeys.Inventory, "Inventory", "Warehouses, stock movements, transfers, batches and valuation.", "inventory_2",
            IsCore: false, IsAvailable: true, Requires: [], Enhances: [ModuleKeys.Billing, ModuleKeys.Purchases, ModuleKeys.Accounting]),
        new(ModuleKeys.Purchases, "Purchases", "Purchase orders, vendor bills, payments made.", "shopping_cart",
            IsCore: false, IsAvailable: true, Requires: [], Enhances: [ModuleKeys.Inventory, ModuleKeys.Accounting]),
        new(ModuleKeys.Accounting, "Accounting", "Chart of accounts, journals, ledgers, bank reconciliation, GST returns.", "account_balance",
            IsCore: false, IsAvailable: true, Requires: [], Enhances: [ModuleKeys.Billing, ModuleKeys.Purchases, ModuleKeys.Inventory]),
        new(ModuleKeys.Operations, "Operations", "Task templates, assignments and delivery tracking.", "task_alt",
            IsCore: false, IsAvailable: true, Requires: [], Enhances: [ModuleKeys.Subscriptions]),
        new(ModuleKeys.Hr, "People", "Employees, attendance, leave and payroll.", "badge",
            IsCore: false, IsAvailable: false, Requires: [], Enhances: [ModuleKeys.Accounting]),
        new(ModuleKeys.Crm, "CRM", "Leads, pipeline, follow-ups and campaigns.", "handshake",
            IsCore: false, IsAvailable: false, Requires: [], Enhances: [ModuleKeys.Billing]),
    ];

    private static readonly Dictionary<string, ModuleDescriptor> ByKey =
        All.ToDictionary(m => m.Key, StringComparer.OrdinalIgnoreCase);

    public static ModuleDescriptor? Find(string key) => ByKey.GetValueOrDefault(key);

    /// <summary>Modules that must also be switched on for <paramref name="key"/> to work.</summary>
    public static IReadOnlyList<string> MissingRequirements(string key, IReadOnlySet<string> enabled)
    {
        if (Find(key) is not { } module) throw new ArgumentException($"Unknown module '{key}'.", nameof(key));
        return module.Requires.Where(r => !enabled.Contains(r)).ToList();
    }

    /// <summary>Enabled modules that would stop working if <paramref name="key"/> were switched off.</summary>
    public static IReadOnlyList<string> Dependents(string key, IReadOnlySet<string> enabled) =>
        All.Where(m => enabled.Contains(m.Key) && m.Requires.Contains(key, StringComparer.OrdinalIgnoreCase))
           .Select(m => m.Key)
           .ToList();

    /// <summary>Normalises a raw entitlement set: adds Core, drops unknown or unavailable keys and
    /// anything whose hard requirements are not met, so a bad row can never half-enable a module.</summary>
    public static IReadOnlySet<string> Effective(IEnumerable<string> granted)
    {
        var set = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { ModuleKeys.Core };
        foreach (string key in granted)
            if (Find(key) is { IsAvailable: true }) set.Add(key);

        bool changed;
        do
        {
            changed = false;
            foreach (string key in set.ToList())
            {
                if (Find(key)!.Requires.Any(r => !set.Contains(r)))
                {
                    set.Remove(key);
                    changed = true;
                }
            }
        } while (changed);

        return set;
    }
}
