# Billing Made Easy — product scope

A multi-tenant billing, inventory and accounting platform for Indian small and mid-sized
businesses, built so that daily work is faster than in Tally, Zoho Books, Vyapar, Marg,
Busy or myBillBook, and the books are correct without an accountant re-entering anything.

This document is the yardstick for every feature: what it is for, who it serves, and why it
beats what's already out there. It is a living document; the decisions in it are the
defaults until changed here.

---

## 1. Who it's for, in order

| Segment | Example | What they need first |
|---|---|---|
| Service businesses | Agencies, consultants, IT, maintenance | Quotations, GST invoices, recurring billing, receivables |
| Traders and retailers | Tyres, hardware, electricals, FMCG distribution | Fast counter billing, stock, purchase, credit control |
| Small manufacturers | Job work, assembly | Purchase, stock by batch, BOM later |
| Accountants serving many clients | CA firms | One login across clients, clean GST returns, Tally export |

**Wedge:** service businesses and traders with 1–25 users who outgrew Excel or Vyapar and
find Tally slow to learn and hard to share. That's where we win first; everything else is
reached through modules.

## 2. Where the market leaves room

| What they do well | Where they fall short | What we do |
|---|---|---|
| **Tally:** keyboard speed, trusted books | Desktop-bound, dated UI, steep learning curve, poor multi-user/remote | Tally-grade keyboard speed in the browser, with a command bar and no memorised menu trees |
| **Zoho Books:** clean UI, integrations | Mouse-heavy, many clicks per invoice, gets expensive with add-ons | Every action reachable in ≤3 keystrokes; modules priced individually |
| **Vyapar / myBillBook:** simple, mobile, cheap | Weak accounting, weak multi-branch and multi-user control | Real double-entry underneath, branches and roles from day one |
| **Marg / Busy:** deep inventory | Complex, desktop, training-dependent | Same depth, revealed progressively; empty screens teach themselves |

Nobody combines **keyboard speed + correct books + modular pricing + per-tenant learning**.
That is the product.

## 3. Principles (each one is a test a feature must pass)

1. **Keyboard first, mouse welcome.** Every screen is fully usable without a mouse. Shortcuts are shown where the action is, not hidden in a help page.
2. **Fewest steps wins.** Count keystrokes to issue an invoice. Target: a repeat customer invoice in under 10 seconds.
3. **The app remembers, so people don't.** Last price per customer and product, usual quantities, default branch, tax and terms, all prefilled and accepted with Enter.
4. **Correct by construction.** Every document posts its own journal. GST is decided by the GSTINs and place of supply, never by a dropdown someone can get wrong.
5. **Explain, don't just refuse.** Errors say what happened and what to do next. A blocked action points to the fix ("Switch on Inventory", "Add a bill-to branch").
6. **Modules stand alone.** Each module works without the others and integrates automatically when its partner is on.
7. **Nothing silently changes history.** Issued documents are immutable; corrections are credit or debit notes. Master changes never rewrite past invoices.
8. **Secure and private by default.** Tenant isolation on every query, audited support access, no secrets in SQL or logs.

## 4. Modules

Every module owns its pages, endpoints, tables and permissions. Switching one on is a single
entitlement row from a plan, a self-serve add-on, a super-admin grant or a trial. The live list
is `ModuleCatalog` in `src/BillingMadeEasy.Core/Modules`.

| Module | Stands alone? | Integrates with | Status |
|---|---|---|---|
| **Essentials** (always on) | — | everything | Sign-in, tenants, users, roles, settings, parties, catalog: built in Web Forms, porting |
| **Billing** | Yes | Inventory (stock out), Accounting (posting) | Quotation → order → invoice → credit note → receipt. Next to build |
| **Subscriptions** | Needs Billing | Operations (deliverables to tasks) | Schema and procedures built (stage 8), screens in progress |
| **Inventory** | Yes | Billing, Purchases, Accounting | Warehouses, movements, transfers, batches/serials, valuation (FIFO/weighted) |
| **Purchases** | Yes | Inventory, Accounting | PO → bill → payment; vendor credit |
| **Accounting** | Yes | Billing, Purchases, Inventory | CoA, journals, ledgers, bank reconciliation, GSTR-1/3B, P&L, balance sheet |
| **Operations** | Yes | Subscriptions | Task templates, assignment, delivery tracking (stage 11) |
| **People (HR)** | Yes | Accounting (payroll posting) | Later: employees, attendance, leave, payroll |
| **CRM** | Yes | Billing (lead → quote) | Later: leads, pipeline, follow-ups, campaigns |

## 5. What makes the work faster

### Keyboard
- **Command bar** (`Ctrl+K` or `/`): go anywhere, find any record, start any action. Ranks by what *this* user in *this* business uses most (built).
- **Go-to chords** (`g` then a letter), shown on hover and in `?` (built).
- **Command grammar (next):** `inv freshbite 4 reels 25k` → invoice draft with customer, item, qty and rate filled. `pay sharma 50000 upi` → receipt. `stock mrf 145/80 r12` → stock card.
- **Grid editing like a spreadsheet:** Enter moves down, Tab across, `Ctrl+D` copy above, `Alt+↓` opens suggestions, `Ctrl+Enter` saves the document.
- **Number shortcuts:** `25k`, `1.5L`, `2cr` expand in amount fields; `+18` adds GST on the fly; `=` evaluates arithmetic.
- **Dates:** `t` today, `y` yesterday, `+7` a week out, `eom` end of month.

### Voice
- Mic in the command bar (built: speech fills the query; nothing runs without Enter).
- Next: dictate a whole invoice. "Invoice FreshBite, four reels, last month's rate" becomes a draft to confirm. Hindi and Hinglish recognition via `en-IN` / `hi-IN`.

### Suggestions learned per tenant
- Last rate per customer and product (price memory, stage 5 resolver).
- Items usually sold together; usual quantity per customer.
- Due-date and terms defaults per customer.
- Anomaly hints: "This rate is 30% below what FreshBite usually pays."

### Fewer screens
- Create-in-place drawers for masters, so a missing customer never leaves the invoice.
- Duplicate detection on GSTIN, phone and name as you type.
- GSTIN lookup fills legal name, address and state (GSTN API, paid; offline checksum built).

## 6. India compliance (non-negotiable for Billing and Accounting)

- GST: CGST+SGST vs IGST from supplier state and place of supply; HSN/SAC; reverse charge; composition scheme; exempt and nil-rated.
- **e-Invoice (IRN + signed QR)** via a GSP/IRP for turnover above the threshold.
- **e-Way bill** generation from invoice or challan.
- GSTR-1 and GSTR-3B exports (JSON for the portal), GSTR-2B reconciliation.
- TDS/TCS on applicable invoices and payments.
- Financial year (Apr–Mar) numbering, with series per branch and document type (built: numbering series).
- Tally XML export and import, so switching is painless and accountants are happy.

## 7. Getting paid

- UPI QR and payment link printed on every invoice; status reconciled from the gateway.
- WhatsApp and email delivery with read status; automatic reminders before and after due date.
- Customer portal: view invoices, pay, download statements, no login (signed link).
- Ageing and credit limit enforcement with an override that's audited (party credit limit built).

## 8. Platform: tenants, plans and self-serve

- One database, `TenantId` on every row, identity global and membership per tenant (built).
- Plans include modules and limits (users, branches, invoices per month); add-ons and trials per module; super-admin grants (schema: `database/scripts/30_module_entitlements.sql`).
- Self-serve: start a trial, upgrade, add a module, pay by UPI or card, invoice issued by the platform from Tenant #1's own books.
- Auto-upgrade prompts at the point of need: hitting a limit or a gated page offers the exact add-on (built: gated pages redirect to Plan with the module highlighted).
- Audited, time-boxed support access instead of a backdoor.

## 9. Security baseline

- PBKDF2-SHA256, 210k iterations, silent rehash on sign-in (built, compatible with existing hashes).
- Cookie auth: HttpOnly, SameSite=Lax, Secure in production; antiforgery on every form (built).
- Per-IP throttling on sign-in; account lockout and security blocks (built; lockout in SQL).
- Strict CSP with no inline script; security headers on every response (built).
- Permission codes on the principal; module gate on every module page and endpoint (built).
- Audit log for every write; separate customer-facing event history on subscriptions.
- Backups: point-in-time restore on the host; tenant-level export on request.

## 10. Roadmap

| Release | Contents | Outcome |
|---|---|---|
| **R0 — Foundation** (this branch) | .NET 10 solution, shell, command bar, module gating, entitlements schema, tests, CI | Runs locally with demo data |
| **R1 — Port** | Sign-in, tenant picker, users and roles, settings, parties, catalog, numbering, subscriptions from Web Forms onto .NET 10 against the existing database | Parity with today's Web Forms app |
| **R2 — First sellable** | Invoice, credit note, receipts, GST reports, PDF and WhatsApp/email, UPI on invoice, command grammar for invoices | A service business can run billing on it |
| **R3 — Trade** | Inventory, purchases, stock valuation, e-way bill | Traders can switch |
| **R4 — Books** | Accounting module, bank reconciliation, GSTR exports, Tally export | Accountants sign off |
| **R5 — Platform** | Self-serve signup, plans, add-ons, trials, platform billing | Grows without manual onboarding |
| **R6 — Expand** | CRM, People, mobile companion, offline counter mode | New modules on the same base |

**Rule for the schedule:** nothing from a later release starts until the current one is
usable end to end. The biggest risk to the timeline is scope creep, not the stack.
