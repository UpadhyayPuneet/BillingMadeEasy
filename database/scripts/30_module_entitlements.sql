/*  30 · Module entitlements: plans, add-ons, platform grants, trials, limits.
    Backs IEntitlementStore. Module keys match ModuleCatalog in BillingMadeEasy.Core.

    NOT YET RUN ANYWHERE. Review before running:
      - Assumes tbl_Tenants has an INT primary key named TenantId. The foreign keys are only
        added when that is true, so the script is safe to run either way, but check the output.
      - Idempotent: safe to run more than once.  */

SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID('dbo.tbl_Plans', 'U') IS NULL
CREATE TABLE dbo.tbl_Plans
(
    PlanId          INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_tbl_Plans PRIMARY KEY,
    PlanCode        VARCHAR(40)   NOT NULL CONSTRAINT UQ_tbl_Plans_Code UNIQUE,
    Name            NVARCHAR(100) NOT NULL,
    MonthlyPrice    DECIMAL(12,2) NOT NULL CONSTRAINT DF_tbl_Plans_Monthly DEFAULT (0),
    YearlyPrice     DECIMAL(12,2) NOT NULL CONSTRAINT DF_tbl_Plans_Yearly DEFAULT (0),
    IsPublic        BIT           NOT NULL CONSTRAINT DF_tbl_Plans_IsPublic DEFAULT (1),
    IsActive        BIT           NOT NULL CONSTRAINT DF_tbl_Plans_IsActive DEFAULT (1),
    SortOrder       INT           NOT NULL CONSTRAINT DF_tbl_Plans_Sort DEFAULT (0),
    CreatedAt       DATETIME2(0)  NOT NULL CONSTRAINT DF_tbl_Plans_Created DEFAULT (SYSUTCDATETIME())
);

/* Modules a plan includes. */
IF OBJECT_ID('dbo.tbl_PlanModules', 'U') IS NULL
CREATE TABLE dbo.tbl_PlanModules
(
    PlanId          INT          NOT NULL CONSTRAINT FK_tbl_PlanModules_Plan REFERENCES dbo.tbl_Plans (PlanId),
    ModuleKey       VARCHAR(40)  NOT NULL,
    CONSTRAINT PK_tbl_PlanModules PRIMARY KEY (PlanId, ModuleKey)
);

/* Limits per plan: users, branches, invoices_per_month. No row = unlimited. */
IF OBJECT_ID('dbo.tbl_PlanLimits', 'U') IS NULL
CREATE TABLE dbo.tbl_PlanLimits
(
    PlanId          INT          NOT NULL CONSTRAINT FK_tbl_PlanLimits_Plan REFERENCES dbo.tbl_Plans (PlanId),
    Meter           VARCHAR(40)  NOT NULL,
    LimitValue      INT          NOT NULL CONSTRAINT CK_tbl_PlanLimits_Positive CHECK (LimitValue >= 0),
    CONSTRAINT PK_tbl_PlanLimits PRIMARY KEY (PlanId, Meter)
);

/* The plan a tenant is on. One current row per tenant. */
IF OBJECT_ID('dbo.tbl_TenantPlans', 'U') IS NULL
CREATE TABLE dbo.tbl_TenantPlans
(
    TenantId        INT          NOT NULL CONSTRAINT PK_tbl_TenantPlans PRIMARY KEY,
    PlanId          INT          NOT NULL CONSTRAINT FK_tbl_TenantPlans_Plan REFERENCES dbo.tbl_Plans (PlanId),
    BillingCycle    TINYINT      NOT NULL CONSTRAINT CK_tbl_TenantPlans_Cycle CHECK (BillingCycle IN (1, 12)),
    CurrentPeriodEnd DATE        NULL,
    ChangedAt       DATETIME2(0) NOT NULL CONSTRAINT DF_tbl_TenantPlans_Changed DEFAULT (SYSUTCDATETIME()),
    ChangedByUserId INT          NULL
);

/* Modules a tenant has on top of the plan.
   Source: 2 = add-on bought by the tenant, 3 = granted by a platform admin, 4 = trial.
   Revoking sets RevokedAt; history is kept, never deleted. */
IF OBJECT_ID('dbo.tbl_TenantModules', 'U') IS NULL
CREATE TABLE dbo.tbl_TenantModules
(
    TenantModuleId  INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_tbl_TenantModules PRIMARY KEY,
    TenantId        INT          NOT NULL,
    ModuleKey       VARCHAR(40)  NOT NULL,
    Source          TINYINT      NOT NULL CONSTRAINT CK_tbl_TenantModules_Source CHECK (Source IN (2, 3, 4)),
    StartsAt        DATETIME2(0) NOT NULL CONSTRAINT DF_tbl_TenantModules_Starts DEFAULT (SYSUTCDATETIME()),
    ExpiresAt       DATETIME2(0) NULL,
    RevokedAt       DATETIME2(0) NULL,
    Reason          NVARCHAR(200) NULL,
    GrantedByUserId INT          NULL,
    CONSTRAINT CK_tbl_TenantModules_Trial CHECK (Source <> 4 OR ExpiresAt IS NOT NULL)
);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_tbl_TenantModules_Active')
CREATE UNIQUE INDEX UX_tbl_TenantModules_Active
    ON dbo.tbl_TenantModules (TenantId, ModuleKey) WHERE RevokedAt IS NULL;

/* Foreign keys to tbl_Tenants, only when its key is INT TenantId. */
IF EXISTS (SELECT 1 FROM sys.columns c JOIN sys.types t ON t.user_type_id = c.user_type_id
           WHERE c.object_id = OBJECT_ID('dbo.tbl_Tenants') AND c.name = 'TenantId' AND t.name = 'int')
BEGIN
    IF OBJECT_ID('dbo.FK_tbl_TenantPlans_Tenant', 'F') IS NULL
        EXEC (N'ALTER TABLE dbo.tbl_TenantPlans ADD CONSTRAINT FK_tbl_TenantPlans_Tenant FOREIGN KEY (TenantId) REFERENCES dbo.tbl_Tenants (TenantId);');
    IF OBJECT_ID('dbo.FK_tbl_TenantModules_Tenant', 'F') IS NULL
        EXEC (N'ALTER TABLE dbo.tbl_TenantModules ADD CONSTRAINT FK_tbl_TenantModules_Tenant FOREIGN KEY (TenantId) REFERENCES dbo.tbl_Tenants (TenantId);');
    PRINT 'Foreign keys to tbl_Tenants added.';
END
ELSE
    PRINT 'tbl_Tenants.TenantId is not INT (or missing): foreign keys skipped. Adjust TenantId types and re-run.';

/* Starter plans. Prices are placeholders: set them before launch. */
MERGE dbo.tbl_Plans AS t
USING (VALUES
    ('start',    N'Start',    0,    0,     10),
    ('grow',     N'Grow',     999,  9990,  20),
    ('business', N'Business', 2499, 24990, 30)
) AS s (PlanCode, Name, MonthlyPrice, YearlyPrice, SortOrder)
ON t.PlanCode = s.PlanCode
WHEN NOT MATCHED THEN INSERT (PlanCode, Name, MonthlyPrice, YearlyPrice, SortOrder)
    VALUES (s.PlanCode, s.Name, s.MonthlyPrice, s.YearlyPrice, s.SortOrder);

INSERT INTO dbo.tbl_PlanModules (PlanId, ModuleKey)
SELECT p.PlanId, m.ModuleKey
FROM dbo.tbl_Plans p
JOIN (VALUES
    ('start', 'billing'),
    ('grow', 'billing'), ('grow', 'inventory'), ('grow', 'purchases'),
    ('business', 'billing'), ('business', 'inventory'), ('business', 'purchases'),
    ('business', 'accounting'), ('business', 'subscriptions'), ('business', 'operations')
) AS m (PlanCode, ModuleKey) ON m.PlanCode = p.PlanCode
WHERE NOT EXISTS (SELECT 1 FROM dbo.tbl_PlanModules x WHERE x.PlanId = p.PlanId AND x.ModuleKey = m.ModuleKey);

INSERT INTO dbo.tbl_PlanLimits (PlanId, Meter, LimitValue)
SELECT p.PlanId, l.Meter, l.LimitValue
FROM dbo.tbl_Plans p
JOIN (VALUES
    ('start', 'users', 1), ('start', 'branches', 1), ('start', 'invoices_per_month', 50),
    ('grow', 'users', 5), ('grow', 'branches', 3),
    ('business', 'users', 25)
) AS l (PlanCode, Meter, LimitValue) ON l.PlanCode = p.PlanCode
WHERE NOT EXISTS (SELECT 1 FROM dbo.tbl_PlanLimits x WHERE x.PlanId = p.PlanId AND x.Meter = l.Meter);

COMMIT TRANSACTION;
GO

/* Three result sets: header row (ResultCode contract), active module grants, limits. */
CREATE OR ALTER PROCEDURE dbo.usp_Tenant_Entitlements_Get
    @TenantId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PlanId INT, @PlanCode VARCHAR(40);
    SELECT @PlanId = tp.PlanId, @PlanCode = p.PlanCode
    FROM dbo.tbl_TenantPlans tp JOIN dbo.tbl_Plans p ON p.PlanId = tp.PlanId
    WHERE tp.TenantId = @TenantId;

    SELECT ResultCode = CASE WHEN @PlanId IS NULL THEN 1 ELSE 0 END,
           ResultMessage = CASE WHEN @PlanId IS NULL THEN 'Tenant has no plan.' ELSE NULL END,
           PlanCode = ISNULL(@PlanCode, '');

    SELECT ModuleKey, Source = CAST(1 AS TINYINT), ExpiresAt = CAST(NULL AS DATETIME2(0))
    FROM dbo.tbl_PlanModules WHERE PlanId = @PlanId
    UNION ALL
    SELECT ModuleKey, Source, ExpiresAt
    FROM dbo.tbl_TenantModules
    WHERE TenantId = @TenantId AND RevokedAt IS NULL AND StartsAt <= SYSUTCDATETIME()
      AND (ExpiresAt IS NULL OR ExpiresAt > SYSUTCDATETIME());

    SELECT Meter, LimitValue FROM dbo.tbl_PlanLimits WHERE PlanId = @PlanId;
END
GO
