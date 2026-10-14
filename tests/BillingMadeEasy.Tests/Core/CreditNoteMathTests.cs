using BillingMadeEasy.Core.Billing;

namespace BillingMadeEasy.Tests.Core;

public sealed class CreditNoteMathTests
{
    // 3 × ₹1,000 at 18% within the state: 3,000 + 270 + 270 = 3,540.
    private static CreditableLine Tyres(decimal creditedQty = 0, decimal creditedTaxable = 0, decimal creditedHalf = 0) =>
        new(1, 3m, 3000m, 18m, 270m, 270m, 0m, false, creditedQty, creditedTaxable, creditedHalf, creditedHalf, 0m);

    [Fact]
    public void A_returned_quantity_takes_back_its_value_and_tax_at_the_invoiced_rate()
    {
        var (line, problem) = CreditNoteMath.Line(Tyres(), new CreditRequest(1, 1m, null), interState: false);
        Assert.Null(problem);
        Assert.Equal((1000m, 90m, 90m, 0m), (line!.Taxable, line.Cgst, line.Sgst, line.Igst));
    }

    [Fact]
    public void Returning_what_is_left_reverses_the_line_to_the_paisa()
    {
        // ₹1,000.01 taxable split over 3: one third is 333.34 each time, rounding would strand paise.
        var odd = new CreditableLine(1, 3m, 1000.01m, 18m, 90m, 90m, 0m, false);
        var (first, _) = CreditNoteMath.Line(odd, new CreditRequest(1, 1m, null), false);
        var after = odd with { CreditedQuantity = 1m, CreditedTaxable = first!.Taxable, CreditedCgst = first.Cgst, CreditedSgst = first.Sgst };
        var (rest, _) = CreditNoteMath.Line(after, new CreditRequest(1, 2m, null), false);
        Assert.Equal(1000.01m, first.Taxable + rest!.Taxable);
        Assert.Equal(180m, first.Tax + rest.Tax);
    }

    [Fact]
    public void Never_more_than_was_billed_counting_earlier_notes()
    {
        Assert.Equal("Only 1 can still be credited", CreditNoteMath.Line(Tyres(2m, 2000m, 180m), new CreditRequest(1, 2m, null), false).Problem);
        Assert.Equal("Only 1000.00 of this line's value can still be credited",
            CreditNoteMath.Line(Tyres(0m, 2000m, 180m), new CreditRequest(1, 0m, 1500m), false).Problem);
        Assert.Equal("Everything on this line has already been credited", CreditNoteMath.Line(Tyres(3m, 3000m, 270m), new CreditRequest(1, 1m, null), false).Problem);
    }

    [Fact]
    public void A_discount_reduces_value_only_and_another_state_is_IGST()
    {
        var line = new CreditableLine(1, 3m, 3000m, 18m, 0m, 0m, 540m, false);
        var (credit, _) = CreditNoteMath.Line(line, new CreditRequest(1, 0m, 300m), interState: true);
        Assert.Equal((0m, 300m, 54m, 0m), (credit!.Quantity, credit.Taxable, credit.Igst, credit.Cgst));
    }

    [Fact]
    public void Reimbursements_carry_no_tax()
    {
        var freight = new CreditableLine(2, 1m, 500m, 0m, 0m, 0m, 0m, IsPureAgent: true);
        var (credit, _) = CreditNoteMath.Line(freight, new CreditRequest(2, 0m, 200m), false);
        var totals = CreditNoteMath.Totals([credit!], roundToRupee: true, invoiceGrandTotal: 4040m, creditedBefore: 0m, settlesEverything: false);
        Assert.Equal((0m, 200m, 200m), (totals.Taxable, totals.Reimbursements, totals.GrandTotal));
    }

    [Fact]
    public void The_last_note_gives_back_exactly_what_the_invoice_has_left()
    {
        // Invoice 3,540.40 rounded to 3,540; an earlier note took 1,180. The final note takes exactly 2,360.
        var lines = new[] { new CreditLineAmounts(1, 2m, 2000.34m, 18m, 180.03m, 180.03m, 0m, false) };
        var totals = CreditNoteMath.Totals(lines, true, invoiceGrandTotal: 3540m, creditedBefore: 1180m, settlesEverything: true);
        Assert.Equal(2360m, totals.GrandTotal);
        Assert.Equal(2360m - 2360.40m, totals.RoundOff);
    }

    [Fact]
    public void Rounded_notes_can_never_add_up_to_more_than_the_invoice()
    {
        var lines = new[] { new CreditLineAmounts(1, 1m, 999.60m, 0m, 0m, 0m, 0m, false) };
        var totals = CreditNoteMath.Totals(lines, true, invoiceGrandTotal: 1999m, creditedBefore: 999m, settlesEverything: false);
        Assert.Equal(1000m, totals.GrandTotal);
        totals = CreditNoteMath.Totals(lines, true, invoiceGrandTotal: 1999m, creditedBefore: 1000m, settlesEverything: false);
        Assert.Equal(999m, totals.GrandTotal);
    }

    [Theory]
    [InlineData("2026-04-01", "2027-11-30")]
    [InlineData("2027-03-31", "2027-11-30")]
    [InlineData("2027-04-01", "2028-11-30")]
    public void GST_allows_a_credit_note_until_30_November_after_the_financial_year(string invoice, string last)
    {
        Assert.Equal(DateOnly.Parse(last), CreditNoteRules.LastDate(DateOnly.Parse(invoice)));
    }
}
