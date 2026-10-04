/*  30 · Module entitlements: plans, add-ons, platform grants, trials, limits.
    Backs IEntitlementStore. Module keys match ModuleCatalog in BillingMadeEasy.Core.

    Run on BME_db after the existing scripts. Idempotent: safe to run more than once.
    Existing businesses with no plan are put on 'business' (every released module), so turning
    this on takes nothing away from anyone. Tested against the BME_db schema exported 4 Oct 2026.  */

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- required by the filtered unique index
SET XACT_ABORT ON;
GO
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
    TenantId        BIGINT       NOT NULL CONSTRAINT PK_tbl_TenantPlans PRIMARY KEY
                                 CONSTRAINT FK_tbl_TenantPlans_Tenant REFERENCES dbo.tbl_Tenants (TenantId),
    PlanId          INT          NOT NULL CONSTRAINT FK_tbl_TenantPlans_Plan REFERENCES dbo.tbl_Plans (PlanId),
    BillingCycle    TINYINT      NOT NULL CONSTRAINT CK_tbl_TenantPlans_Cycle CHECK (BillingCycle IN (1, 12)),
    CurrentPeriodEnd DATE        NULL,
    ChangedAt       DATETIME2(0) NOT NULL CONSTRAINT DF_tbl_TenantPlans_Changed DEFAULT (SYSUTCDATETIME()),
    ChangedByUserId BIGINT       NULL
);

/* Modules a tenant has on top of the plan.
   Source: 2 = add-on bought by the tenant, 3 = granted by a platform admin, 4 = trial.
   Revoking sets RevokedAt; history is kept, never deleted. */
IF OBJECT_ID('dbo.tbl_TenantModules', 'U') IS NULL
CREATE TABLE dbo.tbl_TenantModules
(
    TenantModuleId  BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_tbl_TenantModules PRIMARY KEY,
    TenantId        BIGINT       NOT NULL CONSTRAINT FK_tbl_TenantModules_Tenant REFERENCES dbo.tbl_Tenants (TenantId),
    ModuleKey       VARCHAR(40)  NOT NULL,
    Source          TINYINT      NOT NULL CONSTRAINT CK_tbl_TenantModules_Source CHECK (Source IN (2, 3, 4)),
    StartsAt        DATETIME2(0) NOT NULL CONSTRAINT DF_tbl_TenantModules_Starts DEFAULT (SYSUTCDATETIME()),
    ExpiresAt       DATETIME2(0) NULL,
    RevokedAt       DATETIME2(0) NULL,
    Reason          NVARCHAR(200) NULL,
    GrantedByUserId BIGINT       NULL,
    CONSTRAINT CK_tbl_TenantModules_Trial CHECK (Source <> 4 OR ExpiresAt IS NOT NULL)
);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_tbl_TenantModules_Active')
CREATE UNIQUE INDEX UX_tbl_TenantModules_Active
    ON dbo.tbl_TenantModules (TenantId, ModuleKey) WHERE RevokedAt IS NULL;

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

/* Existing businesses keep everything they have today. */
INSERT INTO dbo.tbl_TenantPlans (TenantId, PlanId, BillingCycle)
SELECT t.TenantId, p.PlanId, 12
FROM dbo.tbl_Tenants t
CROSS JOIN dbo.tbl_Plans p
WHERE p.PlanCode = 'business'
  AND NOT EXISTS (SELECT 1 FROM dbo.tbl_TenantPlans x WHERE x.TenantId = t.TenantId);

COMMIT TRANSACTION;
GO

/* Three result sets: header row (ResultCode contract), active module grants, limits.
   A tenant with no plan row (signed up after this script) falls back to:
     - in trial (tbl_Tenants.Status = 1): every module of 'business', as a trial ending at TrialEndsOnUtc;
     - otherwise: 'start'.  */
CREATE OR ALTER PROCEDURE dbo.usp_Tenant_Entitlements_Get
    @TenantId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @now DATETIME2(0) = SYSUTCDATETIME();
    DECLARE @PlanId INT, @PlanCode VARCHAR(40), @Source TINYINT = 1, @PlanExpires DATETIME2(0) = NULL;

    SELECT @PlanId = tp.PlanId, @PlanCode = p.PlanCode
    FROM dbo.tbl_TenantPlans tp JOIN dbo.tbl_Plans p ON p.PlanId = tp.PlanId
    WHERE tp.TenantId = @TenantId;

    IF @PlanId IS NULL
    BEGIN
        DECLARE @status TINYINT, @trialEnds DATETIME2(3);
        SELECT @status = Status, @trialEnds = TrialEndsOnUtc FROM dbo.tbl_Tenants WHERE TenantId = @TenantId AND IsActive = 1;

        IF @status = 1 AND (@trialEnds IS NULL OR @trialEnds > @now)
            SELECT @PlanId = PlanId, @PlanCode = 'trial', @Source = 4, @PlanExpires = @trialEnds
            FROM dbo.tbl_Plans WHERE PlanCode = 'business';
        ELSE IF @status IS NOT NULL
            SELECT @PlanId = PlanId, @PlanCode = PlanCode FROM dbo.tbl_Plans WHERE PlanCode = 'start';
    END

    SELECT ResultCode = CASE WHEN @PlanId IS NULL THEN 1 ELSE 0 END,
           ResultMessage = CASE WHEN @PlanId IS NULL THEN 'Tenant not found or inactive.' ELSE NULL END,
           PlanCode = ISNULL(@PlanCode, '');

    SELECT ModuleKey, Source = @Source, ExpiresAt = @PlanExpires
    FROM dbo.tbl_PlanModules WHERE PlanId = @PlanId
    UNION ALL
    SELECT ModuleKey, Source, ExpiresAt
    FROM dbo.tbl_TenantModules
    WHERE TenantId = @TenantId AND RevokedAt IS NULL AND StartsAt <= @now
      AND (ExpiresAt IS NULL OR ExpiresAt > @now);

    SELECT Meter, LimitValue FROM dbo.tbl_PlanLimits WHERE PlanId = @PlanId;
END
GO
