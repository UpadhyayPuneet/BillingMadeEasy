namespace BillingMadeEasy.Web.Infrastructure;

/// <summary>
/// Baseline headers on every response. Scripts are same-origin only; inline script is never
/// allowed (page data travels in <c>type="application/json"</c> blocks, which do not execute).
/// </summary>
public static class SecurityHeaders
{
    private const string Csp =
        "default-src 'self'; " +
        "script-src 'self'; " +
        "style-src 'self' https://fonts.googleapis.com; " +
        "font-src 'self' https://fonts.gstatic.com; " +
        "img-src 'self' data:; " +
        "connect-src 'self'; " +
        "form-action 'self'; " +
        "frame-ancestors 'none'; " +
        "base-uri 'self'; " +
        "object-src 'none'";

    public static IApplicationBuilder UseSecurityHeaders(this IApplicationBuilder app) =>
        app.Use(async (context, next) =>
        {
            var headers = context.Response.Headers;
            headers.ContentSecurityPolicy = Csp;
            headers.XContentTypeOptions = "nosniff";
            headers.XFrameOptions = "DENY";
            headers["Referrer-Policy"] = "strict-origin-when-cross-origin";
            headers["Permissions-Policy"] = "camera=(), geolocation=(), payment=(), microphone=(self)";
            headers["Cross-Origin-Opener-Policy"] = "same-origin";
            await next();
        });
}
