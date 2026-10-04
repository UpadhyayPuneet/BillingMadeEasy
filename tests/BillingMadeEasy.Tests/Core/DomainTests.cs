using BillingMadeEasy.Core.Billing;
using BillingMadeEasy.Core.Modules;
using BillingMadeEasy.Core.Tax;

namespace BillingMadeEasy.Tests.Core;

public class GstinTests
{
    [Theory]
    [InlineData("27AAPFU0939F1ZV")]
    [InlineData("29AAGCB7383J1Z4")]
    [InlineData("24AAACC1206D1ZM")]
    [InlineData(" 27aapfu0939f1zv ")]
    public void Valid_numbers_pass(string gstin) => Assert.Equal(GstinCheck.Valid, Gstin.Check(gstin));

    [Theory]
    [InlineData("", GstinCheck.Empty)]
    [InlineData("27AAPFU0939F1Z", GstinCheck.WrongLength)]
    [InlineData("27AAPFU0939F1AV", GstinCheck.WrongFormat)]
    [InlineData("50AAPFU0939F1ZV", GstinCheck.UnknownState)]
    [InlineData("27AAPFU0939F1ZW", GstinCheck.ChecksumMismatch)]
    [InlineData("27AAPFU0938F1ZV", GstinCheck.ChecksumMismatch)]
    public void Invalid_numbers_say_why(string gstin, GstinCheck expected) => Assert.Equal(expected, Gstin.Check(gstin));

    [Fact]
    public void Parts_are_extracted()
    {
        Assert.Equal("27", Gstin.StateCode("27AAPFU0939F1ZV"));
        Assert.Equal("AAPFU0939F", Gstin.Pan("27AAPFU0939F1ZV"));
        Assert.Equal("Maharashtra", StateCodes.Name("27"));
    }

    [Fact]
    public void Same_state_is_intra_state()
    {
        Assert.True(Gstin.IsIntraState("08", "08"));
        Assert.False(Gstin.IsIntraState("08", "07"));
    }
}

public class BillingCalendarTests
{
    [Fact]
    public void Month_end_anchor_survives_february()
    {
        var dates = BillingCalendar.Schedule(new DateOnly(2026, 1, 31), 1, 3).ToList();

        Assert.Equal([new DateOnly(2026, 2, 28), new DateOnly(2026, 3, 31), new DateOnly(2026, 4, 30)], dates);
    }

    [Fact]
    public void Leap_year_february_gets_the_29th()
    {
        Assert.Equal(new DateOnly(2028, 2, 29), BillingCalendar.Next(new DateOnly(2028, 1, 31), 31, 1));
    }

    [Fact]
    public void Quarterly_and_yearly_cross_year_end()
    {
        Assert.Equal(new DateOnly(2027, 2, 28), BillingCalendar.Next(new DateOnly(2026, 11, 30), 31, 3));
        Assert.Equal(new DateOnly(2027, 1, 15), BillingCalendar.Next(new DateOnly(2026, 1, 15), 15, 12));
    }
}

public class ModuleCatalogTests
{
    [Fact]
    public void Core_is_always_on()
    {
        Assert.Contains(ModuleKeys.Core, ModuleCatalog.Effective([]));
    }

    [Fact]
    public void A_module_without_its_requirement_is_not_half_enabled()
    {
        var effective = ModuleCatalog.Effective([ModuleKeys.Subscriptions]);

        Assert.DoesNotContain(ModuleKeys.Subscriptions, effective);
        Assert.Contains(ModuleKeys.Subscriptions, ModuleCatalog.Effective([ModuleKeys.Subscriptions, ModuleKeys.Billing]));
    }

    [Fact]
    public void Unknown_and_unreleased_modules_are_ignored()
    {
        var effective = ModuleCatalog.Effective(["payroll-v9", ModuleKeys.Hr, ModuleKeys.Inventory]);

        Assert.Equal(new HashSet<string> { ModuleKeys.Core, ModuleKeys.Inventory }, effective.ToHashSet());
    }

    [Theory]
    [InlineData(ModuleKeys.Billing)]
    [InlineData(ModuleKeys.Inventory)]
    [InlineData(ModuleKeys.Accounting)]
    [InlineData(ModuleKeys.Purchases)]
    [InlineData(ModuleKeys.Operations)]
    public void Main_modules_stand_alone(string key)
    {
        Assert.Contains(key, ModuleCatalog.Effective([key]));
    }

    [Fact]
    public void Switching_off_billing_reports_what_depends_on_it()
    {
        var enabled = ModuleCatalog.Effective([ModuleKeys.Billing, ModuleKeys.Subscriptions]);

        Assert.Equal([ModuleKeys.Subscriptions], ModuleCatalog.Dependents(ModuleKeys.Billing, enabled));
        Assert.Equal([ModuleKeys.Billing], ModuleCatalog.MissingRequirements(ModuleKeys.Subscriptions, new HashSet<string>()));
    }

    [Fact]
    public void Expired_trials_drop_out()
    {
        var now = DateTimeOffset.UtcNow;
        var tenant = new TenantEntitlements(1, "start",
        [
            new ModuleEntitlement(ModuleKeys.Billing, EntitlementSource.Plan, null),
            new ModuleEntitlement(ModuleKeys.Inventory, EntitlementSource.Trial, now.AddDays(-1)),
            new ModuleEntitlement(ModuleKeys.Accounting, EntitlementSource.Trial, now.AddDays(7)),
        ], new Dictionary<string, int>());

        var enabled = tenant.EnabledModules(now);

        Assert.Contains(ModuleKeys.Billing, enabled);
        Assert.Contains(ModuleKeys.Accounting, enabled);
        Assert.DoesNotContain(ModuleKeys.Inventory, enabled);
    }
}
