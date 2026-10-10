using System.Globalization;

namespace BillingMadeEasy.Web.Infrastructure.Formatting;

/// <summary>Dates as people read them: relative when recent, Indian Standard Time otherwise.</summary>
public static class When
{
    private static readonly TimeZoneInfo Ist = FindIst();
    private static readonly CultureInfo India = CultureInfo.GetCultureInfo("en-IN");

    /// <summary>Today's date in India, whatever the server's clock zone.</summary>
    public static DateTime TodayIst() => TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, Ist).Date;

    public static DateTime ToLocal(DateTime utc) => TimeZoneInfo.ConvertTimeFromUtc(DateTime.SpecifyKind(utc, DateTimeKind.Utc), Ist);

    public static string Ago(DateTime? utc, string never = "—")
    {
        if (utc is null) return never;
        var span = DateTime.UtcNow - DateTime.SpecifyKind(utc.Value, DateTimeKind.Utc);
        if (span < TimeSpan.FromMinutes(1)) return "Just now";
        if (span < TimeSpan.FromHours(1)) return $"{(int)span.TotalMinutes} min ago";
        if (span < TimeSpan.FromHours(24)) return $"{(int)span.TotalHours} h ago";
        var local = ToLocal(utc.Value).Date;
        var today = ToLocal(DateTime.UtcNow).Date;
        if (local == today.AddDays(-1)) return "Yesterday";
        return local.Year == today.Year ? local.ToString("d MMM", India) : local.ToString("d MMM yyyy", India);
    }

    public static string Full(DateTime? utc, string never = "—") =>
        utc is null ? never : ToLocal(utc.Value).ToString("d MMM yyyy, h:mm tt", India);

    private static TimeZoneInfo FindIst()
    {
        foreach (string id in new[] { "Asia/Kolkata", "India Standard Time" })
            if (TimeZoneInfo.TryFindSystemTimeZoneById(id, out var tz)) return tz;
        return TimeZoneInfo.CreateCustomTimeZone("IST", TimeSpan.FromHours(5.5), "India Standard Time", "IST");
    }
}
