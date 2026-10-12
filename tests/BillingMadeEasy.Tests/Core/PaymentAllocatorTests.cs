using BillingMadeEasy.Core.Billing;

namespace BillingMadeEasy.Tests.Core;

public sealed class PaymentAllocatorTests
{
    [Fact]
    public void Money_settles_the_oldest_invoices_first()
    {
        var (allocations, advance) = PaymentAllocator.Oldest(30000m, [new(1, 18570m), new(2, 18570m)]);
        Assert.Equal([new Allocation(1, 18570m, 0), new Allocation(2, 11430m, 0)], allocations);
        Assert.Equal(0m, advance);
    }

    [Fact]
    public void TDS_settles_part_of_an_invoice_without_using_money()
    {
        var (allocations, advance) = PaymentAllocator.Oldest(17070m, [new(1, 18570m, Tds: 1500m), new(2, 5000m)]);
        Assert.Equal([new Allocation(1, 17070m, 1500m)], allocations);
        Assert.Equal(0m, advance);
    }

    [Fact]
    public void Money_beyond_the_invoices_is_an_advance()
    {
        var (allocations, advance) = PaymentAllocator.Oldest(25000m, [new(1, 10000m)]);
        Assert.Single(allocations);
        Assert.Equal(15000m, advance);
    }

    [Fact]
    public void Nothing_owed_means_it_is_all_advance()
    {
        var (allocations, advance) = PaymentAllocator.Oldest(5000m, []);
        Assert.Empty(allocations);
        Assert.Equal(5000m, advance);
    }
}
