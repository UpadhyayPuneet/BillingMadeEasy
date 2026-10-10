using BillingMadeEasy.Core.Modules;
using BillingMadeEasy.Web.Infrastructure.Auth;
using BillingMadeEasy.Web.Infrastructure.Modules;
using Microsoft.AspNetCore.Mvc.ApplicationModels;

namespace BillingMadeEasy.Web.Modules;

/// <summary>GST invoices. The Billing module: on by plan or add-on.</summary>
public sealed class SalesModule : IAppModule
{
    public string Key => ModuleKeys.Billing;

    public string? PagesFolder => "/Sales";

    public IEnumerable<NavItem> Navigation =>
    [
        new("Invoices", "/Sales/Invoices", "receipt_long", "Sales.Invoice.View", Shortcut: "v",
            Keywords: "invoice bill sales tax invoice gst receivable outstanding due"),
        new("New invoice", "/Sales/Invoices/Edit", "post_add", "Sales.Invoice.Create", Keywords: "add create bill invoice sale", Group: "Create"),
        new("Unpaid invoices", "/Sales/Invoices?view=unpaid", "pending_actions", "Sales.Invoice.View", Keywords: "outstanding receivable due collection", Group: "Find"),
        new("Overdue invoices", "/Sales/Invoices?view=overdue", "running_with_errors", "Sales.Invoice.View", Keywords: "late overdue follow up collection", Group: "Find"),
    ];

    public void MapEndpoints(IEndpointRouteBuilder api) { }

    public void ConfigurePages(PageConventionCollection conventions)
    {
        conventions.AuthorizeFolder("/Sales/Invoices", Policies.Permission("Sales.Invoice.View"));
        conventions.AuthorizePage("/Sales/Invoices/Edit", Policies.AnyPermission("Sales.Invoice.Create", "Sales.Invoice.Edit"));
    }
}
