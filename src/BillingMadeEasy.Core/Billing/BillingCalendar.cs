namespace BillingMadeEasy.Core.Billing;

/// <summary>
/// C# twin of <c>fn_NextBillingDate</c>. Each cycle reapplies the anchor day clamped to the month's
/// length, so a subscription anchored on the 31st bills 28 Feb, 31 Mar, 30 Apr — not 28th forever
/// after one pass through February. Used for previews; SQL stays the source of truth for runs.
/// </summary>
public static class BillingCalendar
{
    public static DateOnly Next(DateOnly current, int anchorDay, int intervalMonths)
    {
        ArgumentOutOfRangeException.ThrowIfLessThan(anchorDay, 1);
        ArgumentOutOfRangeException.ThrowIfGreaterThan(anchorDay, 31);
        ArgumentOutOfRangeException.ThrowIfLessThan(intervalMonths, 1);

        DateOnly firstOfTarget = new DateOnly(current.Year, current.Month, 1).AddMonths(intervalMonths);
        int day = Math.Min(anchorDay, DateTime.DaysInMonth(firstOfTarget.Year, firstOfTarget.Month));
        return new DateOnly(firstOfTarget.Year, firstOfTarget.Month, day);
    }

    public static IEnumerable<DateOnly> Schedule(DateOnly start, int intervalMonths, int count)
    {
        DateOnly date = start;
        for (int i = 0; i < count; i++)
        {
            date = Next(date, start.Day, intervalMonths);
            yield return date;
        }
    }
}
