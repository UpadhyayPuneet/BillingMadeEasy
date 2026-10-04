# Billing Made Easy

Billing, inventory and accounting for Indian businesses. Multi-tenant, modular, built to be
used from the keyboard.

- **Scope and roadmap:** [docs/SCOPE.md](docs/SCOPE.md)
- **Moving from Web Forms:** [docs/MIGRATION.md](docs/MIGRATION.md)

## Run it

Needs the [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0).

```powershell
dotnet run --project src/BillingMadeEasy.Web
```

Development signs in against your local `BME_db` (Windows authentication). Once, before the
first run, open `database/scripts/30_module_entitlements.sql` in SSMS against BME_db and run it.
Then sign in with your usual email and password.

No database at hand? Run with demo data instead:

```powershell
dotnet run --project src/BillingMadeEasy.Web -- --Auth:Provider=Demo
```

Demo sign-in: `owner@demo.test` / `Demo@12345` (two businesses with different modules).

Try `Ctrl+K`, `g` then `p`, `?`, and the mic button (Chrome or Edge).

## Test it

```powershell
dotnet test
```

The SQL Server tests build a throwaway database from `database/schema` and `database/scripts`
and drop it afterwards. They run when `BME_TEST_SQL` is set to a server connection whose login
can create databases, and are skipped otherwise:

```powershell
$env:BME_TEST_SQL = "Server=.;Integrated Security=True;TrustServerCertificate=True"
dotnet test
```

## Layout

```
src/
  BillingMadeEasy.Core   Domain rules with no I/O: hashing, GSTIN, billing dates, module catalog
  BillingMadeEasy.Data   Stored-procedure access (Dapper over Microsoft.Data.SqlClient)
  BillingMadeEasy.Web    Razor Pages + Minimal APIs, auth, module gating, shell
tests/
  BillingMadeEasy.Tests  Unit tests and end-to-end tests through the real HTTP pipeline
database/
  schema/   BME_db structure and reference data (builds a new database from scratch)
  legacy/   Schema script of the earlier database design (reference only)
  scripts/  New migrations, numbered after the Web Forms scripts
  tools/    Read-only diagnostic queries
docs/
```

## Configuration

| Key | Default | Meaning |
|---|---|---|
| `ConnectionStrings:BillingMadeEasy` | empty | SQL Server connection |
| `Auth:Provider` | `Sql` | `Demo` uses built-in sample data and is refused outside Development |
| `Auth:SignInRequestsPerMinute` | 10 | Per-IP throttle on sign-in and unlock |
| `Database:CommandTimeoutSeconds` | 30 | Interactive calls |
| `Database:BatchTimeoutSeconds` | 120 | Billing runs |
| `Email:Mode` | `Disabled` (`Pickup` in Development) | `Smtp` sends; `Pickup` writes `.eml` files to `mail-pickup/`; `Disabled` offers the link to share instead |
| `Email:Host`, `Port`, `UserName`, `Password`, `UseStartTls` | — | SMTP server (Office 365: `smtp.office365.com`, 587) |
| `Email:FromAddress`, `FromName` | — | Sender shown on every email |
| `Email:PublicBaseUrl` | request host | Address used in email links, e.g. `https://app.example.in` |
| `Storage:Root` | `App_Data/files` | Uploaded files (logos). Served only to the business that owns them; back this folder up with the database |

Keep real connection strings and SMTP passwords out of the repository: use
`dotnet user-secrets` locally and environment variables on the server, e.g.

```powershell
cd src/BillingMadeEasy.Web
dotnet user-secrets set "Email:Mode" "Smtp"
dotnet user-secrets set "Email:Host" "smtp.office365.com"
dotnet user-secrets set "Email:UserName" "billing@yourdomain.in"
dotnet user-secrets set "Email:Password" "…"
dotnet user-secrets set "Email:FromAddress" "billing@yourdomain.in"
```

## Database scripts

Run every script in `database/scripts` on BME_db, in number order, once. Each is idempotent,
so running one again does no harm.

| Script | Adds |
|---|---|
| `30_module_entitlements.sql` | Plans, add-ons, trials, limits |
| `31_session_lock.sql` | Server-side screen lock |
| `32_party_find_by_gstin.sql` | Duplicate-GSTIN check for new parties |
| `33_party_brand_kit.sql` | Brand kit: dark-background logo, named colours, fonts, tagline, social handles, guidelines |
| `34_catalog_defaults_and_customer_prices.sql` | GST rates (Sep 2025 slabs) and units with UQC for every business, new and existing; customer-specific prices |
| `35_offering_barcode_check.sql` | A duplicate barcode is refused with the name of the item that has it |
