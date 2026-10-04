# Earlier database design

`BME-schema-2026-10-04.sql` is the schema of the `BillingMadeEasy` database as scripted from
SSMS on 4 Oct 2026: 63 tables (`Organizations`, `Users`, `Invoices`, …) and 14 `sp_*`
procedures. **Schema only**: the data rows were removed before committing because they held
customer contact details and a password hash.

It predates the redesign:

- one organization per user (`Users.OrganizationId`), where the redesign has global identity
  and per-tenant membership (`tbl_Users` + `tbl_TenantUsers`);
- separate `PasswordHash` + `PasswordSalt` columns, the single-pass SHA-256 scheme the
  redesign replaced with PBKDF2;
- no `tbl_*` tables or `usp_*` procedures at all.

Kept as a reference: it already covers inventory, purchases and accounting tables the
redesign hasn't reached yet, and those are worth mining when those modules are built.
