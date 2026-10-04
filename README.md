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

Open the URL it prints. In Development it signs in with demo data, no database needed:
`owner@demo.test` / `Demo@12345`. The demo user belongs to two businesses with different
modules switched on, so you can see the picker and module gating.

Try `Ctrl+K`, `g` then `p`, `?`, and the mic button (Chrome or Edge).

## Test it

```powershell
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
  legacy/   Schema script of the earlier database design (reference only)
  scripts/  New migrations, numbered after the Web Forms scripts
  tools/    Read-only diagnostic queries
docs/
```

## Configuration

| Key | Default | Meaning |
|---|---|---|
| `ConnectionStrings:BillingMadeEasy` | empty | SQL Server connection |
| `Auth:Provider` | `Sql` (`Demo` in Development) | `Demo` is refused outside Development |
| `Database:CommandTimeoutSeconds` | 30 | Interactive calls |
| `Database:BatchTimeoutSeconds` | 120 | Billing runs |

Keep real connection strings and SMTP passwords out of the repository: use
`dotnet user-secrets` locally and environment variables on the server.
