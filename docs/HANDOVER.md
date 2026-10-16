# Handover — Billing Made Easy (.NET 10)

Read this first in a new session, together with `CLAUDE.md`, `docs/SCOPE.md` and `docs/MIGRATION.md`.
Last updated after the **credit notes** stage (commit "Credit notes: returns, discounts and over-billing
taken back with their GST").

---

## 1. What this is and how the owner wants it built

A multi-tenant billing, accounting and inventory SaaS for Indian SMBs. HR and CRM come later. It is
a rewrite of an ASP.NET Web Forms app on **.NET 10**. Both apps share one SQL Server database.

The owner's standing instructions (keep them):

- **Quality bar:** production-grade, "best in class", the way leading companies build. Use the most
  professional and standard approach. No gimmicks and nothing fake.
- **Real users:** build what real users need. For every page and function, think about why it
  matters and what it changes for the user.
- **Modular:** each module works on its own and is switched on by plan, by add-on, or by the super
  admin.
- **Input:** keyboard-first, with voice input and auto-suggestions learned per tenant.
- **Autonomy:** do as much as you are sure of in one go, with no need to ask. Changing the database
  (tables, procedures, anything) is allowed when it makes the result better, faster or smoother.
- **Pace:** keep moving to the next step. After each stage: commit and push, then give the owner
  the list of SQL scripts to run.

Paths and accounts:

- **Repo:** `UpadhyayPuneet/BillingMadeEasy`, branch **`claude/charming-turing-auz295`**. All the
  .NET work is on this branch.
- **Owner's local copy:** `D:\Projects\BillingME\BillingME-Core`. Until now it was updated from
  zips; from now on work in a clone of the branch instead.
- **Web Forms original:** `D:\Projects\BillingME\Project\BillingME`. It is the reference for
  porting. Not in git yet; see MIGRATION.md.
- **Database:** **`BME_db`** on local SQL Server (`Data Source=.`, Windows authentication). See
  `appsettings.Development.json`.
- **Not part of this project:** `DesigRightsNew.aspx`, `UserRights.aspx`, `EmployeeMasterN.aspx` and
  `EmployeeMISMaster.aspx` belong to another project. They were mentioned here by mistake; ignore
  them.

## 2. Running it locally (Windows)

```powershell
git clone https://github.com/UpadhyayPuneet/BillingMadeEasy.git
cd BillingMadeEasy
git checkout claude/charming-turing-auz295
dotnet build                                  # warnings are errors
dotnet run --project src/BillingMadeEasy.Web  # Development → BME_db via Windows auth
```

Database: run every script in `database/scripts` on BME_db in number order (30 → 39). Each script
is idempotent, so a rerun does no harm. As of this handover, **39_credit_notes.sql is the newest**.
If the owner hasn't run 36–39 yet, run them in order.

Tests:

```powershell
# unit tests only
dotnet test
# + SQL tests: builds a throwaway database from database/schema + database/scripts
$env:BME_TEST_SQL = "Server=.;Integrated Security=True;TrustServerCertificate=True"
dotnet test
```

The last full run was **166 passed** (Core unit tests plus SQL-backed web-flow tests).
`SqlDatabaseFixture` builds a fresh database for each run, so tests never touch BME_db.

Email in Development is written to `src/BillingMadeEasy.Web/mail-pickup` (pickup mode). For real
SMTP, use the user-secrets commands in the README.

## 3. Architecture (decided — keep consistent)

- **Shape:** Razor Pages plus Minimal APIs. **Dapper over stored procedures only**: no inline SQL
  in C#.
  - Every procedure returns `ResultCode, ResultMessage, …`; `0` means success. Results map to
    `ProcResult` and subclasses, read through `IDb.ResultAsync / SingleAsync / ListAsync / MultipleAsync`.
- **Tenancy:** one database for all tenants, with `TenantId` on every row. TenantId always comes
  from the session claim, never from the request.
- **Transactions:** every write procedure owns its transaction only when no caller has one, so it
  is safe inside a caller's transaction:
  - `DECLARE @own BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END; IF @own=1 BEGIN TRANSACTION ELSE SAVE TRANSACTION sp_x;`
  - On a validation failure: `IF @own=1 ROLLBACK ELSE ROLLBACK TRANSACTION sp_x`, then
    `SELECT ResultCode=5, …`.
  - Known limits: `INSERT…EXEC` can't nest, and a procedure called through `INSERT…EXEC` must not
    roll back.
- **Modules:** `IAppModule` (`src/BillingMadeEasy.Web/Modules/*Module.cs`) declares Key,
  PagesFolder, Navigation (which also feeds the Ctrl+K command bar and the `g x` chords),
  MapEndpoints and ConfigurePages. Gating by `module:{key}` is automatic.
  - Policies: `Policies.Permission("X")` and `Policies.AnyPermission(...)`.
  - Permission codes live in `tbl_Permissions`, for example `Sales.CreditNote.View` and
    `Sales.CreditNote.Manage`.
- **Pages:** page models derive from `TenantPageModel`, which provides `TenantId`, `UserId`,
  `IpAddress`, `Can("perm")` and `Flash` (TempData).
- **Strict CSP:** no inline script and no inline `style` attributes.
  - Page data goes in `<script type="application/json">` or `data-*` attributes.
  - Set styles from JS through the CSSOM.
  - `img-src` allows `data:`, which the UPI QR uses.
- **Shared JS (`wwwroot/js`):**
  - `form.js`: Ctrl+Enter/Ctrl+S saves and Esc cancels. Amount shorthand: 25k, 1.5L, 2cr, `=expr`.
    GSTIN assist. It wires only the **first** `form[data-form]` on a page.
  - `dialogs.js`: `<dialog id="dlg-x">` opened by `data-dialog="x"`, filled from `data-item` JSON;
    `data-default` sets defaults; `data-open="true"` reopens it after a server error.
  - `list.js`: `data-key` single-key actions, live search, row navigation.
  - `keys.js`: `g x` chords. Used letters: **b c h i n p r t u v y**.
- **CSS:** `wwwroot/css/shell.css`, using design tokens. The layout must work at 390px with no
  horizontal scroll; check every new page.
- **Core (`src/BillingMadeEasy.Core`):** pure, tested rules:
  - `Billing/InvoiceMath.cs`: GST arithmetic, amount in words.
  - `Billing/DocumentTypes.cs`: document types, number format, financial year.
  - `Billing/Payments.cs`: payment modes, oldest-first allocator.
  - `Billing/CreditNotes.cs`: reasons, s.34 deadline, credit math.
  - GSTIN, PAN and similar validators.
- **Issued documents are immutable.**
  - A number is taken inside the same transaction as the status change, so there are no gaps.
  - Numbers are at most 16 characters and consecutive per financial year (April to March).
  - A cancelled number stays in `tbl_IssuedNumbers`, marked cancelled.
  - Corrections go through credit or debit notes, never edits.
  - The seller's details are frozen onto the document as JSON (`Seller.cs`).

## 4. What is done (stages, in order)

| Stage | Main pieces |
|---|---|
| Shell, sign-in | Cookie auth over `usp_Auth_*`, lockout, server sessions, idle lock, modules/entitlements (script 30, 31) |
| Parties | Customers/suppliers, GSTIN assist, duplicate guard, branches, contacts, addresses, brand kit (32, 33) |
| Team | Invite → email → welcome → password, roles + permission editor, suspend/remove, password forgot/reset/change |
| Catalogue | Products/services/expenses, GST rates (Sep 2025 slabs; 12%/28% end-dated 21 Sep 2025), units+UQC, customer prices, barcode check (34, 35) |
| Your business | Invoicing profiles (GSTIN, address, logo, signature, accent colour, Udyam, CIN, LUT, composition), bank accounts, number series per profile (36) |
| Invoices | Draft → issue, keyboard-first editor, CGST+SGST / IGST / export (POS 96), inclusive prices, bill of supply for composition, B2C >₹1L address rule, pure-agent reimbursements, plan limit, print A4, UPI QR, cancel (37) |
| Payments | One payment over many invoices oldest-first, TDS separate (26AS), advances + apply, receipt numbers RCT, reversal with reason, duplicate UTR check, s.269ST cash ≥ ₹2L/day refused (38) |
| **Credit notes** | See below (39) |

Credit notes (latest stage):

- **Where to find them:**
  - `/Sales/CreditNotes`: a list with three views (all, with credit left, cancelled) and summary
    tiles.
  - `/Sales/CreditNotes/New?invoiceId=`: always started from an invoice, with key **N** on the
    invoice page.
  - `/Sales/CreditNotes/View/{id}`: the printable document, plus apply, refund, undo-refund and
    cancel.
- **Data model** (script 39):
  - `tbl_CreditNotes`, `tbl_CreditNoteLines` (each line points at a `SalesInvoiceLineId`),
    `tbl_CreditNoteAllocations` and `tbl_CreditNoteRefunds`.
  - `usp_Number_Take` is a shared next-number helper that creates the series on first use. Use it
    for future document types.
  - `fn_CreditNoteLeft` returns the credit still available on a note.
- **Rules:**
  - Line limits on quantity and value count all earlier notes and are checked under a lock on the
    invoice.
  - Tax comes back at the original line's rate and on the same basis as the invoice.
  - The last credit on a line or invoice takes back exactly what remains.
  - s.34 deadline: 30 November after the invoice's financial year.
  - GSTR-1 reason codes 1, 2, 3, 4 and 7.
- **How the money flows:**
  - A note first reduces the invoice's balance. Any surplus is customer credit, which can be
    applied to other invoices from the same profile or refunded.
  - A refund needs a UTR or cheque number and can be undone.
  - Cancelling is blocked while a refund is active. Cancelling restores every balance it reduced.
- **Invoice balance:**
  - `tbl_SalesInvoices.AmountPaid` means "settled so far": money, TDS and credit together.
  - `TdsDeducted` and `CreditedAmount` record the TDS and credit parts.
  - Balance is `GrandTotal - AmountPaid`, so every existing query already counts credit.
  - `Invoice.Received` is the money part only.
- **Knock-on changes:**
  - An invoice with credit notes can't be cancelled; script 39 redefines `usp_SalesInvoice_Cancel`.
  - Record payment tells you when the customer has credit from credit notes.

## 5. Where things are

```
database/schema/            BME_db schema + reference data (baseline the test fixture builds from)
database/scripts/30..39     migrations, idempotent, run in order
src/BillingMadeEasy.Core/   pure rules (Billing/, Tax/, Parties/, Tenancy/…)
src/BillingMadeEasy.Data/   IDb (Dapper); ProcResult is in Core/Results.cs
src/BillingMadeEasy.Web/
  Modules/                  IAppModule per area (Sales = Billing module key)
  Features/<Area>/          stores (one per area, thin wrappers over procedures) + view types
  Pages/<Area>/             Razor pages
  wwwroot/js, css           shared + per-page scripts (invoice.js, payment.js, credit-note.js…)
tests/BillingMadeEasy.Tests/
  Core/                     unit tests
  Sql/                      web-flow tests against a throwaway DB (SalesSetup builds a ready business)
```

Pattern for a new document stage, in the order used for invoices, payments and credit notes:

1. A Core rule class with unit tests.
2. Script `NN_*.sql`: tables, then procedures with `@own` transactions, validation as
   `ResultCode=5` with a plain message, and an audit row in `tbl_AuditLog`.
3. A store in `Features/Sales`.
4. Pages: Index, the `_Rows` partial for live search, New/Edit, and View with dialogs.
5. Navigation and conventions in the module, and DI registration in `Program.cs`.
6. SQL web-flow tests.
7. A browser check at desktop size and at 390px.
8. A README script-table row, then commit and push.

## 6. Next steps (suggested order)

1. **Customer statement / ledger.**
   - Invoices, payments, credit notes and refunds per customer, with opening balance, running
     balance and an ageing summary (0–30, 31–60, 61–90, 90+).
   - Printable and shareable; reached from the party page and from Record payment.
   - All the data already exists.
2. **Payment reminders** by email or WhatsApp.
   - Overdue lists, templated messages with the UPI link or QR, reminder history, opt-out.
   - Email sending already exists in `Features/Account`; WhatsApp needs a provider decision from
     the owner.
3. **Debit notes:** the same shape as credit notes, document type 4, for increases.
4. **Quotations / proforma** (type 5), then **delivery challans** (type 6).
5. **GST reports:** GSTR-1 (B2B, B2CL, B2CS, CDNR/CDNUR from credit notes, HSN summary) and a
   GSTR-3B summary.
6. **Inventory:** stock movements from invoices and credit-note returns (reason code 1 carries
   quantities).
7. **Older open items:**
   - OTP sign-in, PIN unlock and trusted devices.
   - Confirm the party and address type labels with the owner.
   - E-invoice (IRN) and e-way bill later.

Points to confirm with the owner when they come up:

- **Credit note number format.** Series created from defaults format as `CN-2026-27-0001`;
  receipts look like `RCT-26-27-0001`. The difference comes from the series' YearFormat and can be
  changed under Your business → numbering.
- **Walk-in customers** (no party record) can get credit notes but can only be refunded, since
  there is no account to carry a credit.

## 7. Gotchas learned the hard way

- `form.js` wires only the first `form[data-form]` on a page. Forms inside dialogs should not carry
  `data-form`; `dialogs.js` handles Ctrl+Enter there.
- **Bind a form only on its own handler** (`[FromForm(Name="Form")]` on the handler parameter),
  not as a page-wide `[BindProperty]`. Otherwise a dialog post on the same page fails validation
  silently.
- A `data-x="@(cond ? "true" : null)"` attribute renders as empty, not missing, so JS checks
  `=== 'true'`.
- A submit button that is disabled before the browser reads the form drops its name and value.
  `form.js` disables it on a `setTimeout`.
- Late lookup results must not reopen a list after the user has moved on; check `activeElement`.
- A CTE covers one statement only. A second `SELECT` in the same procedure can't use it (this hit
  the credit-note list summary).
- Test hosts set `hostBuilder:reloadConfigOnChange=false`. Otherwise a full test run exhausts the
  inotify watches on Linux.
- `LINENO` is a reserved word, so the column is called `LineNumber`.
- When a customer has a GSTIN but no address state, the place of supply comes from the GSTIN's
  first two digits.

## 8. Housekeeping

- The previous cloud session had a routine, **"Resume interrupted work"**
  (`trig_01Y74V8zPEw5nHKi31inNdnR`), firing every 5 hours into that session. It is no longer
  needed; delete it from the Routines list on claude.ai if it is still there.
- No pull request has been opened. Merge or open one when the owner asks.
