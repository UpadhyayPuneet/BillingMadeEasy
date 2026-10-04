using BillingMadeEasy.Web.Infrastructure.Auth;
using BillingMadeEasy.Web.Infrastructure.Email;

namespace BillingMadeEasy.Web.Features.Team;

/// <param name="Link">The one-time link, shown to the inviter only when the email didn't go,
/// so they can pass it on another way (WhatsApp, in person).</param>
public sealed record InviteDelivery(EmailOutcome Email, string? Link);

/// <summary>Issues a 24-hour invite token and emails the welcome link.</summary>
public sealed class InviteSender(AccountTokens tokens, EmailService email)
{
    public async Task<InviteDelivery?> SendAsync(HttpRequest request, Guid publicId, long userId, string fullName, string emailAddress,
        long tenantId, string tenantName, string inviterName, string? ip, CancellationToken ct)
    {
        var token = await tokens.IssueAsync(userId, tenantId, TokenType.Invite, emailAddress, ip, ct);
        if (token is null) return null;

        string link = email.PublicUrl(request, $"/Account/Welcome?u={publicId:N}&t={Uri.EscapeDataString(token.Token)}");
        var outcome = await email.SendTemplateAsync("AUTH_USER_INVITE", emailAddress, fullName, new Dictionary<string, string>
        {
            ["FullName"] = fullName,
            ["InviterName"] = inviterName,
            ["TenantName"] = tenantName,
            ["InviteLink"] = link,
            ["ValidityHours"] = Math.Max(1, token.ValidityMinutes / 60).ToString(),
            ["Preheader"] = $"{inviterName} invited you to {tenantName}",
        }, tenantId, userId, "TenantUser", null, ct);

        return new InviteDelivery(outcome, outcome == EmailOutcome.Sent ? null : link);
    }
}
