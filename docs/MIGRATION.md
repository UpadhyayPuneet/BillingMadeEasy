# Moving from Web Forms to .NET 10

The Web Forms project (`D:\Projects\BillingME\Project\BillingME`) keeps running until each
area is ported and checked. The database is shared: both apps talk to the same SQL Server
database and the same stored procedures, so nothing has to be migrated twice.

## What is kept as-is

| Web Forms | .NET 10 | Notes |
|---|---|---|
| `tbl_*` tables, `usp_*` procedures | Same | The procedures are the contract. `IDb` calls them with Dapper |
| `ResultCode, ResultMessage, …` single-row results | `ProcResult` + `IDb.ResultAsync<T>` | Codes map to user wording in C#, never in SQL |
| `ClassSecurity.HashPassword` | `PasswordHasher` | Same `PBKDF2$SHA256$210000$salt$hash` format: existing passwords keep working |
| `KeyGenerator` | `SecureTokens` | `RandomNumberGenerator`; check `Hash` encoding against `ClassSecurity` before reusing old tokens |
| `IsGSTValid` | `Gstin` | Same checksum, plus a reason for each failure |
| `fn_NextBillingDate` | `BillingCalendar` | C# twin for previews; SQL stays authoritative |
| `tokens.css`, `patterns.css`, `drawer.js` | `wwwroot/css`, `wwwroot/js` | Copy over; the shell's `tokens.css` is a stand-in until then |

## What changes

| Web Forms | .NET 10 |
|---|---|
| `.aspx` + code-behind | Razor Page (`.cshtml` + `PageModel`) |
| `.ashx` JSON handlers | Minimal API endpoints in the module's `MapEndpoints` |
| `ClassOperations` + Hashtable | `IDb` with typed anonymous parameters |
| `AuthModule` + `SecurePage` | Cookie auth + fallback policy + `module:` / `perm:` policies |
| `BillingPrincipal` permission set | Permission claims, checked with `perm:Code` policies |
| `NavigationMap` | `IAppModule.Navigation` (also feeds the command bar) |
| `Site.Master` | `Pages/Shared/_Layout.cshtml` |
| `web.config` | `appsettings.json` + user secrets / environment variables |

## Order

1. **Get the code and scripts into the repository** (below). Nothing else can be ported faithfully without them.
2. ~~Find the database holding the redesign.~~ Done: it is **`BME_db`** (see `database/legacy/README.md`). `BillingMadeEasy` is the earlier design.
3. ~~Port sign-in.~~ Done: `SqlAuthService` over the `usp_Auth_*` procedures, with the lockout ladder, server sessions re-checked on every request, idle lock and unlock, and silent hash upgrade. Tested against a database built from `database/schema`.
4. Run `database/scripts/30_module_entitlements.sql` on BME_db once. `SqlEntitlementStore` is wired.
   Still to port from Web Forms: OTP sign-in, PIN unlock and trusted devices, forgot/reset password, invite acceptance, must-change-password.
5. Port screen by screen. Done: **parties** (list, create/edit with GSTIN assist and duplicate guard, branches, contacts, addresses, brands, status) and **team** (people, invite → email → welcome → password, roles and the permission editor, suspend/remove, ownership). Next: settings → catalog → numbering → subscriptions. Each one becomes an `IAppModule` folder.
   Note: invite links issued by the Web Forms app won't open in the new one (different token hashing); resend from the new Team page.
6. Build the invoice (stage 9) on .NET 10 only.

## Getting the project into GitHub

From a terminal in `D:\Projects\BillingME\Project\BillingME`:

```powershell
git init
git checkout -b main
```

First create a `.gitignore` there containing at least `bin/`, `obj/`, `packages/`, `.vs/`,
`*.user` and `Web.config` (it holds the SMTP password and connection string; commit a
`Web.config.example` with those blanked instead). Then:

```powershell
git add .
git commit -m "Web Forms project as of today"
git remote add origin https://github.com/UpadhyayPuneet/BillingMadeEasy.git
git push -u origin main
```

Put every SQL script you ran (01 to 22 and anything after) in a `Database` folder before
the commit. If Git asks you to sign in, use the browser prompt.

This .NET 10 work is on the `claude/charming-turing-auz295` branch. Once `main` has the Web
Forms code, the two are merged (they don't overlap: this branch only adds `src/`, `tests/`,
`database/` and `docs/`).
