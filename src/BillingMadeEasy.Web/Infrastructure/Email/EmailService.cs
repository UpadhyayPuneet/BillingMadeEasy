using System.Net;
using System.Text.RegularExpressions;
using BillingMadeEasy.Core;
using BillingMadeEasy.Data;
using MailKit.Net.Smtp;
using MailKit.Security;
using MimeKit;

namespace BillingMadeEasy.Web.Infrastructure.Email;

public sealed class EmailOptions
{
    /// <summary><c>Smtp</c> sends; <c>Pickup</c> writes .eml files to <see cref="PickupDirectory"/> (development);
    /// <c>Disabled</c> sends nothing and reports it, so callers can offer another route.</summary>
    public string Mode { get; set; } = "Disabled";
    public string FromAddress { get; set; } = "";
    public string FromName { get; set; } = "Billing Made Easy";
    public string Host { get; set; } = "";
    public int Port { get; set; } = 587;
    public string? UserName { get; set; }
    public string? Password { get; set; }
    public bool UseStartTls { get; set; } = true;
    public string PickupDirectory { get; set; } = "mail-pickup";
    /// <summary>Public address of the app, used to build links in emails (no trailing slash).</summary>
    public string PublicBaseUrl { get; set; } = "";
}

public enum EmailOutcome
{
    Sent,
    Failed,
    Disabled,
    Suppressed,
}

/// <summary>
/// Template-driven email: resolves the tenant's (or platform) template, fills placeholders,
/// logs the message in tbl_CommunicationLog, sends, and records the outcome. A send that fails
/// is visible in the log and to the caller; it is never swallowed.
/// </summary>
public sealed partial class EmailService(IDb db, EmailOptions options, ILogger<EmailService> log, IWebHostEnvironment env)
{
    private sealed class Template : ProcResult
    {
        public string TemplateCode { get; init; } = "";
        public string Subject { get; init; } = "";
        public string? BodyHtml { get; init; }
        public string? BodyText { get; init; }
    }

    private sealed class LogRow : ProcResult
    {
        public long CommunicationLogId { get; init; }
    }

    [GeneratedRegex(@"\{\{\s*([A-Za-z0-9_]+)\s*\}\}")]
    private static partial Regex Placeholder();

    public bool CanSend => !string.Equals(options.Mode, "Disabled", StringComparison.OrdinalIgnoreCase);

    public string PublicUrl(HttpRequest request, string pathAndQuery)
    {
        string baseUrl = string.IsNullOrWhiteSpace(options.PublicBaseUrl)
            ? $"{request.Scheme}://{request.Host}"
            : options.PublicBaseUrl.TrimEnd('/');
        return baseUrl + pathAndQuery;
    }

    public async Task<EmailOutcome> SendTemplateAsync(
        string templateCode, string to, string toName, IReadOnlyDictionary<string, string> values,
        long? tenantId, long? userId, string? relatedEntity = null, long? relatedId = null, CancellationToken ct = default)
    {
        var template = await db.SingleAsync<Template>("dbo.usp_Comm_Template_Resolve",
            new { TenantId = tenantId, TemplateCode = templateCode, Channel = (byte)1, LanguageCode = "en" }, ct);
        if (template is null || template.TemplateCode.Length == 0)
            throw new InvalidOperationException($"Email template {templateCode} is missing.");

        string subject = Fill(template.Subject, values, html: false);
        string? html = template.BodyHtml is null ? null : Fill(template.BodyHtml, values, html: true);
        string? text = template.BodyText is null ? null : Fill(template.BodyText, values, html: false);

        // The rendered body holds the secret link; the log keeps the subject and a redacted copy.
        var logged = await db.ResultAsync<LogRow>("dbo.usp_Comm_Log_Insert", new
        {
            TenantId = tenantId,
            UserId = userId,
            TemplateCode = templateCode,
            Channel = (byte)1,
            SentTo = to,
            Subject = subject,
            BodyRendered = Redact(text ?? subject, values),
            RelatedEntityName = relatedEntity,
            RelatedEntityId = relatedId,
        }, ct);

        if (!CanSend)
        {
            await UpdateAsync(logged.CommunicationLogId, 4, null, "Email sending is not configured", ct);
            return EmailOutcome.Disabled;
        }

        try
        {
            var message = new MimeMessage();
            message.From.Add(new MailboxAddress(options.FromName, options.FromAddress));
            message.To.Add(new MailboxAddress(toName, to));
            message.Subject = subject;
            message.Body = new BodyBuilder { HtmlBody = html, TextBody = text }.ToMessageBody();

            string? providerId;
            if (string.Equals(options.Mode, "Pickup", StringComparison.OrdinalIgnoreCase))
            {
                string dir = Path.IsPathRooted(options.PickupDirectory) ? options.PickupDirectory : Path.Combine(env.ContentRootPath, options.PickupDirectory);
                Directory.CreateDirectory(dir);
                string file = Path.Combine(dir, $"{DateTime.UtcNow:yyyyMMdd-HHmmss}-{templateCode}-{logged.CommunicationLogId}.eml");
                await message.WriteToAsync(file, ct);
                providerId = Path.GetFileName(file);
            }
            else
            {
                using var smtp = new SmtpClient();
                await smtp.ConnectAsync(options.Host, options.Port, options.UseStartTls ? SecureSocketOptions.StartTls : SecureSocketOptions.Auto, ct);
                if (!string.IsNullOrEmpty(options.UserName))
                    await smtp.AuthenticateAsync(options.UserName, options.Password ?? "", ct);
                providerId = await smtp.SendAsync(message, ct);
                await smtp.DisconnectAsync(true, ct);
            }

            await UpdateAsync(logged.CommunicationLogId, 2, providerId, null, ct);
            return EmailOutcome.Sent;
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            log.LogError(e, "Sending {Template} to {To} failed", templateCode, to);
            await UpdateAsync(logged.CommunicationLogId, 3, null, e.Message.Length > 500 ? e.Message[..500] : e.Message, ct);
            return EmailOutcome.Failed;
        }
    }

    private Task UpdateAsync(long id, byte status, string? providerId, string? error, CancellationToken ct) =>
        db.ResultAsync<ProcResult>("dbo.usp_Comm_Log_UpdateStatus",
            new { CommunicationLogId = id, Status = status, ProviderMessageId = providerId, ErrorMessage = error }, ct);

    private static string Fill(string template, IReadOnlyDictionary<string, string> values, bool html) =>
        Placeholder().Replace(template, m =>
            values.TryGetValue(m.Groups[1].Value, out var v) ? (html ? WebUtility.HtmlEncode(v) : v) : "");

    private static string Redact(string body, IReadOnlyDictionary<string, string> values)
    {
        foreach (var (key, value) in values)
            if (key.EndsWith("Link", StringComparison.Ordinal) || key == "Code")
                body = body.Replace(value, "[redacted]", StringComparison.Ordinal);
        return body;
    }
}
