# Billing Made Easy — working notes

Multi-tenant billing/inventory/accounting SaaS for Indian SMBs. ASP.NET Core 10 (Razor Pages +
Minimal APIs), SQL Server via stored procedures, Dapper. Being ported from an ASP.NET Web Forms
app that shares the same database. Product scope: `docs/SCOPE.md`. Port plan: `docs/MIGRATION.md`.

## Commands

- Build: `dotnet build` (warnings are errors)
- Test: `dotnet test`
- Run: `dotnet run --project src/BillingMadeEasy.Web` (Development uses demo sign-in: `owner@demo.test` / `Demo@12345`)

## Rules that are decided

- **One database, `TenantId` on every row.** Identity is global (`tbl_Users`); membership is per tenant (`tbl_TenantUsers`). Every tenant-scoped procedure takes `@TenantId` from the session claim, never from the request body.
- **Stored procedures only.** No inline SQL in C#. Every procedure returns one row `ResultCode, ResultMessage, …`; `0` is success. User-facing wording is mapped in C#.
- **Secrets never reach SQL.** Hash in C# (`PasswordHasher`, `SecureTokens`); SQL compares hashes.
- **Modules are independent.** A module is an `IAppModule` (navigation + endpoints) plus a `Pages/{Folder}`. Its pages and endpoints are gated by `module:{key}` automatically. Hard dependencies go in `ModuleCatalog.Requires`; soft integrations in `Enhances` and must no-op when the partner is off.
- **Authorization:** fallback policy requires a signed-in user with a tenant selected. Use `perm:{Code}` policies for actions. Anonymous access is granted per page, never per folder.
- **Issued documents are immutable.** Corrections are credit/debit notes. Masters are copied into documents and subscriptions, never referenced for printed values.
- **No inline script** (CSP `script-src 'self'`). Pass page data in `<script type="application/json">`.
- **Keyboard first.** Every new screen: reachable from the command bar, shortcuts listed in `?`, usable without a mouse, Enter/Esc behave predictably.
- **JSON API writes** (when added) must validate antiforgery via the `RequestVerificationToken` header.

## Style

- File-scoped namespaces, primary constructors, `sealed` by default, nullable on.
- Comments explain *why*, briefly; match the surrounding density.
- User-facing text: plain, specific, says what to do next. No "Error occurred".
