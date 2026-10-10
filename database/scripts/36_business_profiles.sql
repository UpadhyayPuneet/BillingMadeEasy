/* 36 · Your business: who the invoice is from
   ------------------------------------------------------------------
   A tax invoice must carry the supplier's name, address and GSTIN (Rule 46),
   and the state in that GSTIN decides CGST+SGST or IGST. None of that had a
   home: tbl_Tenants holds only a name and a tax number.

   tbl_BusinessProfiles is "the business as it appears on an invoice". Most
   businesses have one. Some invoice under more than one name — a proprietor
   who also runs an LLP, a firm with a second trading brand, a branch with its
   own GSTIN in another state — and each of those is a profile with its own
   logo, colours, bank accounts and numbering series.

   Numbering moves under the profile because the law asks for one consecutive
   run per GSTIN, and two profiles must never print the same number.

   Safe to run more than once. */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('dbo.tbl_BusinessProfiles') IS NULL
CREATE TABLE dbo.tbl_BusinessProfiles
(
    BusinessProfileId    BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_BusinessProfiles PRIMARY KEY,
    TenantId             BIGINT          NOT NULL,
    ProfileName          NVARCHAR(150)   NOT NULL,   -- the name customers know: "Yenetch"
    LegalName            NVARCHAR(200)   NOT NULL,   -- as registered: "Yenetch Technologies LLP"
    Gstin                VARCHAR(15)     NULL,
    Pan                  CHAR(10)        NULL,
    StateCode            VARCHAR(10)     NULL,       -- GST state code; from the GSTIN when there is one
    AddressLine1         NVARCHAR(150)   NULL,
    AddressLine2         NVARCHAR(150)   NULL,
    City                 NVARCHAR(80)    NULL,
    PostalCode           VARCHAR(10)     NULL,
    Phone                VARCHAR(20)     NULL,
    Email                NVARCHAR(150)   NULL,
    Website              NVARCHAR(200)   NULL,
    LogoPath             NVARCHAR(300)   NULL,
    SignaturePath        NVARCHAR(300)   NULL,
    SignatoryName        NVARCHAR(120)   NULL,
    SignatoryTitle       NVARCHAR(80)    NULL,
    AccentColor          CHAR(7)         NULL,       -- headings and rules on the printed invoice
    UdyamNumber          VARCHAR(19)     NULL,       -- MSME: buyers must pay within 45 days (MSMED Act s.15)
    Cin                  VARCHAR(21)     NULL,       -- companies must print it (Companies Act s.12)
    IsComposition        BIT             NOT NULL CONSTRAINT DF_BusinessProfiles_Composition DEFAULT (0),
    LutNumber            NVARCHAR(30)    NULL,       -- exports without IGST under a Letter of Undertaking
    InvoiceTerms         NVARCHAR(2000)  NULL,
    InvoiceNote          NVARCHAR(500)   NULL,
    DefaultDueDays       SMALLINT        NULL,
    RoundOffTotal        BIT             NOT NULL CONSTRAINT DF_BusinessProfiles_RoundOff DEFAULT (1),
    IsDefault            BIT             NOT NULL CONSTRAINT DF_BusinessProfiles_IsDefault DEFAULT (0),
    IsActive             BIT             NOT NULL CONSTRAINT DF_BusinessProfiles_IsActive DEFAULT (1),
    CreatedAtUtc         DATETIME2(3)    NOT NULL CONSTRAINT DF_BusinessProfiles_Created DEFAULT (SYSUTCDATETIME()),
    CreatedBy            BIGINT          NULL,
    UpdatedAtUtc         DATETIME2(3)    NULL,
    UpdatedBy            BIGINT          NULL,
    CONSTRAINT FK_BusinessProfiles_Tenant FOREIGN KEY (TenantId) REFERENCES dbo.tbl_Tenants (TenantId),
    CONSTRAINT CK_BusinessProfiles_DueDays CHECK (DefaultDueDays IS NULL OR DefaultDueDays BETWEEN 0 AND 365)
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_BusinessProfiles_Default')
    CREATE UNIQUE INDEX UX_BusinessProfiles_Default ON dbo.tbl_BusinessProfiles (TenantId)
        WHERE IsDefault = 1 AND IsActive = 1;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_BusinessProfiles_Gstin')
    CREATE UNIQUE INDEX UX_BusinessProfiles_Gstin ON dbo.tbl_BusinessProfiles (TenantId, Gstin)
        WHERE Gstin IS NOT NULL AND IsActive = 1;
GO

IF OBJECT_ID('dbo.tbl_BusinessBankAccounts') IS NULL
CREATE TABLE dbo.tbl_BusinessBankAccounts
(
    BankAccountId        BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_BusinessBankAccounts PRIMARY KEY,
    TenantId             BIGINT          NOT NULL,
    BusinessProfileId    BIGINT          NOT NULL,
    BankName             NVARCHAR(100)   NOT NULL,
    AccountName          NVARCHAR(150)   NOT NULL,
    AccountNumber        VARCHAR(20)     NOT NULL,
    Ifsc                 CHAR(11)        NOT NULL,
    BranchName           NVARCHAR(100)   NULL,
    AccountType          TINYINT         NOT NULL CONSTRAINT DF_BankAccounts_Type DEFAULT (1),  -- 1 current, 2 savings, 3 cash credit / OD
    UpiId                VARCHAR(60)     NULL,
    IsDefault            BIT             NOT NULL CONSTRAINT DF_BankAccounts_Default DEFAULT (0),
    IsActive             BIT             NOT NULL CONSTRAINT DF_BankAccounts_Active DEFAULT (1),
    CreatedAtUtc         DATETIME2(3)    NOT NULL CONSTRAINT DF_BankAccounts_Created DEFAULT (SYSUTCDATETIME()),
    CreatedBy            BIGINT          NULL,
    UpdatedAtUtc         DATETIME2(3)    NULL,
    UpdatedBy            BIGINT          NULL,
    CONSTRAINT FK_BankAccounts_Profile FOREIGN KEY (BusinessProfileId) REFERENCES dbo.tbl_BusinessProfiles (BusinessProfileId)
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_BankAccounts_Default')
    CREATE UNIQUE INDEX UX_BankAccounts_Default ON dbo.tbl_BusinessBankAccounts (BusinessProfileId)
        WHERE IsDefault = 1 AND IsActive = 1;
GO

/* ── Numbering belongs to a profile ── */
IF COL_LENGTH('dbo.tbl_NumberSeries', 'BusinessProfileId') IS NULL
    ALTER TABLE dbo.tbl_NumberSeries ADD BusinessProfileId BIGINT NULL
        CONSTRAINT FK_NumberSeries_Profile REFERENCES dbo.tbl_BusinessProfiles (BusinessProfileId);
GO

/* One default per profile and document type, not per business. */
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_Series_Default' AND object_id = OBJECT_ID('dbo.tbl_NumberSeries'))
   AND NOT EXISTS (SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
                    JOIN sys.indexes i ON i.object_id = ic.object_id AND i.index_id = ic.index_id
                   WHERE i.name = 'UX_Series_Default' AND c.name = 'BusinessProfileId')
    DROP INDEX UX_Series_Default ON dbo.tbl_NumberSeries;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_Series_Default' AND object_id = OBJECT_ID('dbo.tbl_NumberSeries'))
    CREATE UNIQUE INDEX UX_Series_Default ON dbo.tbl_NumberSeries (TenantId, BusinessProfileId, DocumentType)
        WHERE IsDefault = 1 AND IsActive = 1;
GO

/* A numbering run that outgrows its padding widens instead of wrapping. */
CREATE OR ALTER FUNCTION [dbo].[fn_FormatDocNumber]
      (@Prefix NVARCHAR(15), @Suffix NVARCHAR(15), @Separator NVARCHAR(3),
       @YearFormat TINYINT, @FinancialYear SMALLINT, @Sequence INT, @PadWidth TINYINT)
RETURNS NVARCHAR(40)
AS
BEGIN
    DECLARE @year NVARCHAR(10) =
        CASE @YearFormat
             WHEN 1 THEN CONCAT(@FinancialYear, '-', RIGHT(CONCAT('0', @FinancialYear + 1 - 2000), 2))
             WHEN 2 THEN CONCAT(RIGHT(CONCAT('0', @FinancialYear - 2000), 2), '-',
                                RIGHT(CONCAT('0', @FinancialYear + 1 - 2000), 2))
             WHEN 3 THEN CAST(@FinancialYear AS NVARCHAR(4))
             ELSE NULL
        END;

    /* Padded to the width, never cut to it: the 10,000th number in a 4-digit
       series is 10000, not 0000 (which would collide with the first). */
    DECLARE @digits NVARCHAR(12) = CAST(@Sequence AS NVARCHAR(12));
    DECLARE @padded NVARCHAR(12) =
        CASE WHEN LEN(@digits) >= @PadWidth THEN @digits
             ELSE RIGHT(REPLICATE('0', @PadWidth) + @digits, @PadWidth) END;

    /* Built left to right, skipping any part that is null, so a series with no
       prefix does not come out as "-26-27-0001". */
    DECLARE @result NVARCHAR(40) = N'';

    IF @Prefix IS NOT NULL AND LEN(@Prefix) > 0 SET @result = @Prefix;
    IF @year IS NOT NULL
        SET @result = CASE WHEN LEN(@result) > 0 THEN @result + @Separator + @year ELSE @year END;

    SET @result = CASE WHEN LEN(@result) > 0 THEN @result + @Separator + @padded ELSE @padded END;

    IF @Suffix IS NOT NULL AND LEN(@Suffix) > 0 SET @result = @result + @Separator + @Suffix;

    RETURN @result;
END
GO

/* ============================================================================
   DEFAULTS: every business can raise an invoice on day one
   ========================================================================= */
CREATE OR ALTER PROCEDURE dbo.usp_Business_EnsureDefaults
    @TenantId BIGINT,
    @Silent   BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @profileId BIGINT;

    SELECT @profileId = BusinessProfileId FROM dbo.tbl_BusinessProfiles
     WHERE TenantId = @TenantId AND IsDefault = 1 AND IsActive = 1;

    IF @profileId IS NULL
    BEGIN
        SELECT TOP (1) @profileId = BusinessProfileId FROM dbo.tbl_BusinessProfiles
         WHERE TenantId = @TenantId AND IsActive = 1 ORDER BY BusinessProfileId;

        IF @profileId IS NOT NULL
            UPDATE dbo.tbl_BusinessProfiles SET IsDefault = 1 WHERE BusinessProfileId = @profileId;
    END

    IF @profileId IS NULL
    BEGIN
        /* Start from what signup recorded. A tax number that is a well-formed
           GSTIN is taken as one, along with its state and PAN. */
        INSERT INTO dbo.tbl_BusinessProfiles
              (TenantId, ProfileName, LegalName, Gstin, Pan, StateCode, Phone, Email, IsDefault)
        SELECT t.TenantId, t.DisplayName, t.LegalName,
               g.Gstin,
               CASE WHEN g.Gstin IS NULL THEN NULL ELSE SUBSTRING(g.Gstin, 3, 10) END,
               CASE WHEN g.Gstin IS NULL THEN NULL ELSE LEFT(g.Gstin, 2) END,
               t.ContactPhone, t.ContactEmail, 1
          FROM dbo.tbl_Tenants t
         CROSS APPLY (SELECT Gstin = CASE WHEN UPPER(t.TaxNumber) LIKE '[0-3][0-9][A-Z][A-Z][A-Z][A-Z][A-Z][0-9][0-9][0-9][0-9][A-Z][1-9A-Z]Z[0-9A-Z]'
                                          THEN UPPER(t.TaxNumber) END) g
         WHERE t.TenantId = @TenantId;

        SET @profileId = SCOPE_IDENTITY();
    END

    /* Series made before profiles existed belong to the default profile. */
    UPDATE dbo.tbl_NumberSeries SET BusinessProfileId = @profileId
     WHERE TenantId = @TenantId AND BusinessProfileId IS NULL;

    /* A tax invoice series: INV-26-27-0001. 14 characters, inside the 16 the
       GST rules allow, and it resets each April. */
    IF @profileId IS NOT NULL AND NOT EXISTS
       (SELECT 1 FROM dbo.tbl_NumberSeries
         WHERE TenantId = @TenantId AND BusinessProfileId = @profileId AND DocumentType = 1 AND IsActive = 1)
        INSERT INTO dbo.tbl_NumberSeries
              (TenantId, BusinessProfileId, DocumentType, SeriesName, Prefix, Suffix, PadWidth, Separator,
               YearFormat, ResetYearly, StartFrom, IsDefault, IsActive, CreatedAtUtc)
        VALUES(@TenantId, @profileId, 1, N'Tax invoices', N'INV', NULL, 4, N'-', 2, 1, 1, 1, 1, SYSUTCDATETIME());

    IF @Silent = 0
        SELECT ResultCode = 0, ResultMessage = N'Ok', BusinessProfileId = @profileId;
END
GO

CREATE OR ALTER TRIGGER dbo.trg_Tenants_BusinessDefaults ON dbo.tbl_Tenants
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id BIGINT;
    DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT TenantId FROM inserted;
    OPEN c;
    FETCH NEXT FROM c INTO @id;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC dbo.usp_Business_EnsureDefaults @TenantId = @id, @Silent = 1;
        FETCH NEXT FROM c INTO @id;
    END
    CLOSE c;
    DEALLOCATE c;
END
GO

DECLARE @t BIGINT;
DECLARE existing CURSOR LOCAL FAST_FORWARD FOR SELECT TenantId FROM dbo.tbl_Tenants;
OPEN existing;
FETCH NEXT FROM existing INTO @t;
WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC dbo.usp_Business_EnsureDefaults @TenantId = @t, @Silent = 1;
    FETCH NEXT FROM existing INTO @t;
END
CLOSE existing;
DEALLOCATE existing;
GO

/* ============================================================================
   PROFILES
   ========================================================================= */
CREATE OR ALTER PROCEDURE dbo.usp_BusinessProfile_List
    @TenantId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT p.BusinessProfileId, p.ProfileName, p.LegalName, p.Gstin, p.StateCode, s.StateName,
           p.City, p.LogoPath, p.AccentColor, p.IsComposition, p.IsDefault, p.IsActive,
           BankAccounts = (SELECT COUNT(*) FROM dbo.tbl_BusinessBankAccounts b
                            WHERE b.BusinessProfileId = p.BusinessProfileId AND b.IsActive = 1),
           NextInvoiceNumber = (SELECT TOP (1) dbo.fn_FormatDocNumber(n.Prefix, n.Suffix, n.Separator, n.YearFormat,
                                       dbo.fn_FinancialYear(CAST(SYSUTCDATETIME() AS DATE)),
                                       ISNULL(c.NextNumber, n.StartFrom), n.PadWidth)
                                  FROM dbo.tbl_NumberSeries n
                                  LEFT JOIN dbo.tbl_NumberCounters c ON c.SeriesId = n.SeriesId
                                       AND c.FinancialYear = CASE WHEN n.ResetYearly = 0 THEN 0
                                                                  ELSE dbo.fn_FinancialYear(CAST(SYSUTCDATETIME() AS DATE)) END
                                 WHERE n.BusinessProfileId = p.BusinessProfileId AND n.DocumentType = 1
                                   AND n.IsActive = 1 AND n.IsDefault = 1),
           Missing = CONCAT_WS(N', ',
                        CASE WHEN p.AddressLine1 IS NULL THEN N'address' END,
                        CASE WHEN p.StateCode IS NULL THEN N'state' END,
                        CASE WHEN p.LogoPath IS NULL THEN N'logo' END,
                        CASE WHEN NOT EXISTS (SELECT 1 FROM dbo.tbl_BusinessBankAccounts b
                                               WHERE b.BusinessProfileId = p.BusinessProfileId AND b.IsActive = 1)
                             THEN N'bank account' END)
      FROM dbo.tbl_BusinessProfiles p
      LEFT JOIN dbo.tbl_StateCodes s ON s.CountryCode = 'IN' AND s.StateCode = p.StateCode
     WHERE p.TenantId = @TenantId
     ORDER BY p.IsActive DESC, p.IsDefault DESC, p.ProfileName;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_BusinessProfile_Get
    @TenantId          BIGINT,
    @BusinessProfileId BIGINT = NULL   -- null: the default
AS
BEGIN
    SET NOCOUNT ON;

    IF @BusinessProfileId IS NULL
        SELECT @BusinessProfileId = BusinessProfileId FROM dbo.tbl_BusinessProfiles
         WHERE TenantId = @TenantId AND IsDefault = 1 AND IsActive = 1;

    SELECT p.*, s.StateName
      FROM dbo.tbl_BusinessProfiles p
      LEFT JOIN dbo.tbl_StateCodes s ON s.CountryCode = 'IN' AND s.StateCode = p.StateCode
     WHERE p.BusinessProfileId = @BusinessProfileId AND p.TenantId = @TenantId;

    SELECT b.BankAccountId, b.BankName, b.AccountName, b.AccountNumber, b.Ifsc, b.BranchName,
           b.AccountType, b.UpiId, b.IsDefault
      FROM dbo.tbl_BusinessBankAccounts b
     WHERE b.BusinessProfileId = @BusinessProfileId AND b.TenantId = @TenantId AND b.IsActive = 1
     ORDER BY b.IsDefault DESC, b.BankName;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_BusinessProfile_Save
    @TenantId          BIGINT,
    @BusinessProfileId BIGINT = 0,
    @ProfileName       NVARCHAR(150),
    @LegalName         NVARCHAR(200),
    @Gstin             VARCHAR(15)    = NULL,
    @Pan               CHAR(10)       = NULL,
    @StateCode         VARCHAR(10)    = NULL,
    @AddressLine1      NVARCHAR(150)  = NULL,
    @AddressLine2      NVARCHAR(150)  = NULL,
    @City              NVARCHAR(80)   = NULL,
    @PostalCode        VARCHAR(10)    = NULL,
    @Phone             VARCHAR(20)    = NULL,
    @Email             NVARCHAR(150)  = NULL,
    @Website           NVARCHAR(200)  = NULL,
    @SignatoryName     NVARCHAR(120)  = NULL,
    @SignatoryTitle    NVARCHAR(80)   = NULL,
    @AccentColor       CHAR(7)        = NULL,
    @UdyamNumber       VARCHAR(19)    = NULL,
    @Cin               VARCHAR(21)    = NULL,
    @IsComposition     BIT            = 0,
    @LutNumber         NVARCHAR(30)   = NULL,
    @InvoiceTerms      NVARCHAR(2000) = NULL,
    @InvoiceNote       NVARCHAR(500)  = NULL,
    @DefaultDueDays    SMALLINT       = NULL,
    @RoundOffTotal     BIT            = 1,
    @IsDefault         BIT            = 0,
    @ActionByUserId    BIGINT,
    @IpAddress         VARCHAR(45)    = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @isNew BIT = CASE WHEN @BusinessProfileId > 0 THEN 0 ELSE 1 END;
    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();

    SET @ProfileName = LTRIM(RTRIM(ISNULL(@ProfileName, '')));
    SET @LegalName   = LTRIM(RTRIM(ISNULL(@LegalName, '')));
    SET @Gstin       = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@Gstin, '')))), '');
    SET @Pan         = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@Pan, '')))), '');

    IF LEN(@ProfileName) < 2
    BEGIN SELECT ResultCode = 5, ResultMessage = N'Enter the name customers know you by', FieldName = 'ProfileName'; RETURN; END
    IF LEN(@LegalName) < 2
    BEGIN SELECT ResultCode = 5, ResultMessage = N'Enter the legal name, as registered', FieldName = 'LegalName'; RETURN; END

    /* The GSTIN decides the state and contains the PAN. Saying so beats
       storing three facts that disagree. */
    IF @Gstin IS NOT NULL
    BEGIN
        IF @StateCode IS NULL SET @StateCode = LEFT(@Gstin, 2);
        IF @StateCode <> LEFT(@Gstin, 2)
        BEGIN SELECT ResultCode = 5, ResultMessage = N'The GSTIN is registered in a different state from the one chosen', FieldName = 'StateCode'; RETURN; END
        IF @Pan IS NULL SET @Pan = SUBSTRING(@Gstin, 3, 10);
        IF @Pan <> SUBSTRING(@Gstin, 3, 10)
        BEGIN SELECT ResultCode = 5, ResultMessage = CONCAT(N'The PAN inside this GSTIN is ', SUBSTRING(@Gstin, 3, 10)), FieldName = 'Pan'; RETURN; END
        IF EXISTS (SELECT 1 FROM dbo.tbl_BusinessProfiles WHERE TenantId = @TenantId AND Gstin = @Gstin
                      AND IsActive = 1 AND BusinessProfileId <> @BusinessProfileId)
        BEGIN SELECT ResultCode = 5, ResultMessage = N'Another profile already uses this GSTIN', FieldName = 'Gstin'; RETURN; END
    END

    IF @StateCode IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.tbl_StateCodes WHERE CountryCode = 'IN' AND StateCode = @StateCode)
    BEGIN SELECT ResultCode = 5, ResultMessage = N'Choose a state from the list', FieldName = 'StateCode'; RETURN; END

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @isNew = 0 AND NOT EXISTS (SELECT 1 FROM dbo.tbl_BusinessProfiles WHERE BusinessProfileId = @BusinessProfileId AND TenantId = @TenantId)
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT ResultCode = 1, ResultMessage = N'That profile no longer exists';
            RETURN;
        END

        IF @IsDefault = 1
            UPDATE dbo.tbl_BusinessProfiles SET IsDefault = 0, UpdatedAtUtc = @now, UpdatedBy = @ActionByUserId
             WHERE TenantId = @TenantId AND IsDefault = 1 AND BusinessProfileId <> @BusinessProfileId;
        ELSE IF @isNew = 0 AND EXISTS (SELECT 1 FROM dbo.tbl_BusinessProfiles WHERE BusinessProfileId = @BusinessProfileId AND IsDefault = 1)
            SET @IsDefault = 1;   -- the default stays default until another is chosen

        IF @isNew = 1
        BEGIN
            INSERT INTO dbo.tbl_BusinessProfiles
                  (TenantId, ProfileName, LegalName, Gstin, Pan, StateCode, AddressLine1, AddressLine2, City, PostalCode,
                   Phone, Email, Website, SignatoryName, SignatoryTitle, AccentColor, UdyamNumber, Cin, IsComposition,
                   LutNumber, InvoiceTerms, InvoiceNote, DefaultDueDays, RoundOffTotal, IsDefault, CreatedBy)
            VALUES(@TenantId, @ProfileName, @LegalName, @Gstin, @Pan, @StateCode, @AddressLine1, @AddressLine2, @City, @PostalCode,
                   @Phone, @Email, @Website, @SignatoryName, @SignatoryTitle, @AccentColor, @UdyamNumber, @Cin, @IsComposition,
                   @LutNumber, @InvoiceTerms, @InvoiceNote, @DefaultDueDays, @RoundOffTotal, @IsDefault, @ActionByUserId);
            SET @BusinessProfileId = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE dbo.tbl_BusinessProfiles
               SET ProfileName = @ProfileName, LegalName = @LegalName, Gstin = @Gstin, Pan = @Pan, StateCode = @StateCode,
                   AddressLine1 = @AddressLine1, AddressLine2 = @AddressLine2, City = @City, PostalCode = @PostalCode,
                   Phone = @Phone, Email = @Email, Website = @Website, SignatoryName = @SignatoryName,
                   SignatoryTitle = @SignatoryTitle, AccentColor = @AccentColor, UdyamNumber = @UdyamNumber, Cin = @Cin,
                   IsComposition = @IsComposition, LutNumber = @LutNumber, InvoiceTerms = @InvoiceTerms,
                   InvoiceNote = @InvoiceNote, DefaultDueDays = @DefaultDueDays, RoundOffTotal = @RoundOffTotal,
                   IsDefault = @IsDefault, UpdatedAtUtc = @now, UpdatedBy = @ActionByUserId
             WHERE BusinessProfileId = @BusinessProfileId AND TenantId = @TenantId;

        /* A new profile can invoice at once: it gets its own series, with a
           prefix no other series in this business uses. */
        IF @isNew = 1
        BEGIN
            DECLARE @prefix NVARCHAR(15) = N'INV', @n INT = 2;
            WHILE EXISTS (SELECT 1 FROM dbo.tbl_NumberSeries WHERE TenantId = @TenantId AND DocumentType = 1
                             AND IsActive = 1 AND ISNULL(Prefix, N'') = @prefix)
            BEGIN
                SET @prefix = CONCAT(N'INV', @n);
                SET @n += 1;
            END
            INSERT INTO dbo.tbl_NumberSeries
                  (TenantId, BusinessProfileId, DocumentType, SeriesName, Prefix, PadWidth, Separator,
                   YearFormat, ResetYearly, StartFrom, IsDefault, IsActive, CreatedAtUtc, CreatedBy)
            VALUES(@TenantId, @BusinessProfileId, 1, N'Tax invoices', @prefix, 4, N'-', 2, 1, 1, 1, 1, @now, @ActionByUserId);
        END

        INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, IpAddress)
        VALUES(@TenantId, @ActionByUserId, CASE WHEN @isNew = 1 THEN 'Business.ProfileCreated' ELSE 'Business.ProfileUpdated' END,
               'BusinessProfile', @BusinessProfileId, @ProfileName,
               CONCAT(CASE WHEN @isNew = 1 THEN N'Added ' ELSE N'Updated ' END, @ProfileName), @IpAddress);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok', BusinessProfileId = @BusinessProfileId, IsNew = @isNew;
END
GO

/* @Kind 1 = logo, 2 = signature. Returns the old file so the caller can delete it. */
CREATE OR ALTER PROCEDURE dbo.usp_BusinessProfile_SetImage
    @TenantId          BIGINT,
    @BusinessProfileId BIGINT,
    @Kind              TINYINT,
    @Path              NVARCHAR(300) = NULL,
    @ActionByUserId    BIGINT,
    @IpAddress         VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @old NVARCHAR(300), @name NVARCHAR(150);

    SELECT @old = CASE @Kind WHEN 1 THEN LogoPath ELSE SignaturePath END, @name = ProfileName
      FROM dbo.tbl_BusinessProfiles WHERE BusinessProfileId = @BusinessProfileId AND TenantId = @TenantId;

    IF @name IS NULL OR @Kind NOT IN (1, 2)
    BEGIN SELECT ResultCode = 1, ResultMessage = N'That profile no longer exists'; RETURN; END

    UPDATE dbo.tbl_BusinessProfiles
       SET LogoPath      = CASE WHEN @Kind = 1 THEN @Path ELSE LogoPath END,
           SignaturePath = CASE WHEN @Kind = 2 THEN @Path ELSE SignaturePath END,
           UpdatedAtUtc = SYSUTCDATETIME(), UpdatedBy = @ActionByUserId
     WHERE BusinessProfileId = @BusinessProfileId AND TenantId = @TenantId;

    INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, IpAddress)
    VALUES(@TenantId, @ActionByUserId, CASE WHEN @Kind = 1 THEN 'Business.LogoChanged' ELSE 'Business.SignatureChanged' END,
           'BusinessProfile', @BusinessProfileId, @name,
           CONCAT(CASE WHEN @Path IS NULL THEN N'Removed ' ELSE N'Changed ' END,
                  CASE WHEN @Kind = 1 THEN N'logo' ELSE N'signature' END, N' for ', @name), @IpAddress);

    SELECT ResultCode = 0, ResultMessage = N'Ok', OldPath = @old;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_BusinessProfile_SetActive
    @TenantId          BIGINT,
    @BusinessProfileId BIGINT,
    @IsActive          BIT,
    @ActionByUserId    BIGINT,
    @IpAddress         VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @name NVARCHAR(150), @isDefault BIT;

    SELECT @name = ProfileName, @isDefault = IsDefault FROM dbo.tbl_BusinessProfiles
     WHERE BusinessProfileId = @BusinessProfileId AND TenantId = @TenantId;

    IF @name IS NULL BEGIN SELECT ResultCode = 1, ResultMessage = N'That profile no longer exists'; RETURN; END
    IF @IsActive = 0 AND @isDefault = 1
    BEGIN SELECT ResultCode = 5, ResultMessage = N'Make another profile the default before retiring this one'; RETURN; END

    UPDATE dbo.tbl_BusinessProfiles SET IsActive = @IsActive, UpdatedAtUtc = SYSUTCDATETIME(), UpdatedBy = @ActionByUserId
     WHERE BusinessProfileId = @BusinessProfileId AND TenantId = @TenantId;

    INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, IpAddress)
    VALUES(@TenantId, @ActionByUserId, CASE WHEN @IsActive = 1 THEN 'Business.ProfileRestored' ELSE 'Business.ProfileRetired' END,
           'BusinessProfile', @BusinessProfileId, @name,
           CONCAT(CASE WHEN @IsActive = 1 THEN N'Restored ' ELSE N'Retired ' END, @name), @IpAddress);

    SELECT ResultCode = 0, ResultMessage = N'Ok';
END
GO

/* ============================================================================
   BANK ACCOUNTS: printed on the invoice so the customer pays the right one
   ========================================================================= */
CREATE OR ALTER PROCEDURE dbo.usp_BankAccount_Save
    @TenantId          BIGINT,
    @BusinessProfileId BIGINT,
    @BankAccountId     BIGINT = 0,
    @BankName          NVARCHAR(100),
    @AccountName       NVARCHAR(150),
    @AccountNumber     VARCHAR(20),
    @Ifsc              CHAR(11),
    @BranchName        NVARCHAR(100) = NULL,
    @AccountType       TINYINT = 1,
    @UpiId             VARCHAR(60) = NULL,
    @IsDefault         BIT = 0,
    @ActionByUserId    BIGINT,
    @IpAddress         VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();
    SET @Ifsc = UPPER(LTRIM(RTRIM(ISNULL(@Ifsc, ''))));
    SET @AccountNumber = REPLACE(LTRIM(RTRIM(ISNULL(@AccountNumber, ''))), ' ', '');
    SET @UpiId = NULLIF(LOWER(LTRIM(RTRIM(ISNULL(@UpiId, '')))), '');

    IF NOT EXISTS (SELECT 1 FROM dbo.tbl_BusinessProfiles WHERE BusinessProfileId = @BusinessProfileId AND TenantId = @TenantId)
    BEGIN SELECT ResultCode = 1, ResultMessage = N'That profile no longer exists'; RETURN; END

    /* IFSC: 4 letters (bank), a zero, 6 characters (branch). */
    IF @Ifsc NOT LIKE '[A-Z][A-Z][A-Z][A-Z]0[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]'
    BEGIN SELECT ResultCode = 5, ResultMessage = N'An IFSC is 11 characters: 4 letters, a zero, then 6 letters or digits (e.g. HDFC0001234)', FieldName = 'Ifsc'; RETURN; END
    IF @AccountNumber LIKE '%[^0-9]%' OR LEN(@AccountNumber) NOT BETWEEN 6 AND 18
    BEGIN SELECT ResultCode = 5, ResultMessage = N'An account number is 6 to 18 digits', FieldName = 'AccountNumber'; RETURN; END
    IF @UpiId IS NOT NULL AND @UpiId NOT LIKE '_%@_%'
    BEGIN SELECT ResultCode = 5, ResultMessage = N'A UPI ID looks like name@bank', FieldName = 'UpiId'; RETURN; END
    IF EXISTS (SELECT 1 FROM dbo.tbl_BusinessBankAccounts WHERE BusinessProfileId = @BusinessProfileId AND IsActive = 1
                  AND AccountNumber = @AccountNumber AND Ifsc = @Ifsc AND BankAccountId <> @BankAccountId)
    BEGIN SELECT ResultCode = 5, ResultMessage = N'This account is already added', FieldName = 'AccountNumber'; RETURN; END

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.tbl_BusinessBankAccounts WHERE BusinessProfileId = @BusinessProfileId
                          AND IsActive = 1 AND BankAccountId <> @BankAccountId)
            SET @IsDefault = 1;   -- the only account is the one printed

        IF @IsDefault = 1
            UPDATE dbo.tbl_BusinessBankAccounts SET IsDefault = 0, UpdatedAtUtc = @now, UpdatedBy = @ActionByUserId
             WHERE BusinessProfileId = @BusinessProfileId AND IsDefault = 1 AND BankAccountId <> @BankAccountId;

        IF @BankAccountId > 0
        BEGIN
            UPDATE dbo.tbl_BusinessBankAccounts
               SET BankName = @BankName, AccountName = @AccountName, AccountNumber = @AccountNumber, Ifsc = @Ifsc,
                   BranchName = @BranchName, AccountType = @AccountType, UpiId = @UpiId,
                   IsDefault = CASE WHEN @IsDefault = 1 THEN 1 ELSE IsDefault END,
                   UpdatedAtUtc = @now, UpdatedBy = @ActionByUserId
             WHERE BankAccountId = @BankAccountId AND BusinessProfileId = @BusinessProfileId AND TenantId = @TenantId AND IsActive = 1;
            IF @@ROWCOUNT = 0
            BEGIN ROLLBACK TRANSACTION; SELECT ResultCode = 1, ResultMessage = N'That account no longer exists'; RETURN; END
        END
        ELSE
        BEGIN
            INSERT INTO dbo.tbl_BusinessBankAccounts
                  (TenantId, BusinessProfileId, BankName, AccountName, AccountNumber, Ifsc, BranchName, AccountType, UpiId, IsDefault, CreatedBy)
            VALUES(@TenantId, @BusinessProfileId, @BankName, @AccountName, @AccountNumber, @Ifsc, @BranchName, @AccountType, @UpiId, @IsDefault, @ActionByUserId);
            SET @BankAccountId = SCOPE_IDENTITY();
        END

        INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, IpAddress)
        VALUES(@TenantId, @ActionByUserId, 'Business.BankAccountSaved', 'BankAccount', @BankAccountId,
               CONCAT(@BankName, N' ••', RIGHT(@AccountNumber, 4)),
               CONCAT(N'Bank account ', @BankName, N' ending ', RIGHT(@AccountNumber, 4), N' saved'), @IpAddress);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok', BankAccountId = @BankAccountId;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_BankAccount_Remove
    @TenantId          BIGINT,
    @BusinessProfileId BIGINT,
    @BankAccountId     BIGINT,
    @ActionByUserId    BIGINT,
    @IpAddress         VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @wasDefault BIT, @label NVARCHAR(150);

    SELECT @wasDefault = IsDefault, @label = CONCAT(BankName, N' ending ', RIGHT(AccountNumber, 4))
      FROM dbo.tbl_BusinessBankAccounts
     WHERE BankAccountId = @BankAccountId AND BusinessProfileId = @BusinessProfileId AND TenantId = @TenantId AND IsActive = 1;

    IF @label IS NULL BEGIN SELECT ResultCode = 1, ResultMessage = N'That account no longer exists'; RETURN; END

    BEGIN TRANSACTION;
    /* Kept, not deleted: invoices already sent print the account they named. */
    UPDATE dbo.tbl_BusinessBankAccounts SET IsActive = 0, IsDefault = 0, UpdatedAtUtc = SYSUTCDATETIME(), UpdatedBy = @ActionByUserId
     WHERE BankAccountId = @BankAccountId;

    IF @wasDefault = 1
        UPDATE TOP (1) dbo.tbl_BusinessBankAccounts SET IsDefault = 1
         WHERE BusinessProfileId = @BusinessProfileId AND IsActive = 1;

    INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, IpAddress)
    VALUES(@TenantId, @ActionByUserId, 'Business.BankAccountRemoved', 'BankAccount', @BankAccountId, @label,
           CONCAT(N'Removed ', @label), @IpAddress);
    COMMIT TRANSACTION;

    SELECT ResultCode = 0, ResultMessage = N'Ok';
END
GO

/* ============================================================================
   NUMBERING, per profile
   ========================================================================= */
CREATE OR ALTER PROCEDURE dbo.usp_NumberSeries_ListForProfile
    @TenantId          BIGINT,
    @BusinessProfileId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @year SMALLINT = dbo.fn_FinancialYear(CAST(SYSUTCDATETIME() AS DATE));

    SELECT s.SeriesId, s.DocumentType, s.SeriesName, s.Prefix, s.Suffix, s.Separator,
           s.PadWidth, s.YearFormat, s.ResetYearly, s.StartFrom, s.IsDefault,
           NextSequence = ISNULL(c.NextNumber, s.StartFrom),
           NextNumber = dbo.fn_FormatDocNumber(s.Prefix, s.Suffix, s.Separator, s.YearFormat,
                            @year, ISNULL(c.NextNumber, s.StartFrom), s.PadWidth),
           IssuedTotal = (SELECT COUNT(*) FROM dbo.tbl_IssuedNumbers i WHERE i.SeriesId = s.SeriesId),
           IssuedThisYear = (SELECT COUNT(*) FROM dbo.tbl_IssuedNumbers i
                              WHERE i.SeriesId = s.SeriesId
                                AND i.FinancialYear = CASE WHEN s.ResetYearly = 0 THEN 0 ELSE @year END),
           LastNumber = (SELECT TOP (1) i.FullNumber FROM dbo.tbl_IssuedNumbers i
                          WHERE i.SeriesId = s.SeriesId ORDER BY i.IssuedNumberId DESC),
           c.LastIssuedUtc
      FROM dbo.tbl_NumberSeries s
      LEFT JOIN dbo.tbl_NumberCounters c
             ON c.SeriesId = s.SeriesId
            AND c.FinancialYear = CASE WHEN s.ResetYearly = 0 THEN 0 ELSE @year END
     WHERE s.TenantId = @TenantId AND s.BusinessProfileId = @BusinessProfileId AND s.IsActive = 1
     ORDER BY s.DocumentType, s.IsDefault DESC, s.SeriesName;
END
GO

/* Wraps usp_NumberSeries_Save with what a per-profile series needs: the
   profile link, the 16-character limit, and no prefix clash. */
CREATE OR ALTER PROCEDURE dbo.usp_NumberSeries_SaveForProfile
    @TenantId          BIGINT,
    @BusinessProfileId BIGINT,
    @SeriesId          BIGINT       = 0,
    @DocumentType      TINYINT,
    @SeriesName        NVARCHAR(60),
    @Prefix            NVARCHAR(15) = NULL,
    @Suffix            NVARCHAR(15) = NULL,
    @Separator         NVARCHAR(3)  = '-',
    @PadWidth          TINYINT      = 4,
    @YearFormat        TINYINT      = 2,
    @ResetYearly       BIT          = 1,
    @StartFrom         INT          = 1,
    @IsDefault         BIT          = 0,
    @ActionByUserId    BIGINT,
    @IpAddress         VARCHAR(45)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Prefix = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@Prefix, '')))), '');
    SET @Suffix = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@Suffix, '')))), '');
    SET @Separator = ISNULL(@Separator, '');

    IF NOT EXISTS (SELECT 1 FROM dbo.tbl_BusinessProfiles WHERE BusinessProfileId = @BusinessProfileId AND TenantId = @TenantId)
    BEGIN SELECT ResultCode = 1, ResultMessage = N'That profile no longer exists'; RETURN; END

    IF @SeriesId > 0 AND NOT EXISTS (SELECT 1 FROM dbo.tbl_NumberSeries WHERE SeriesId = @SeriesId
                                         AND TenantId = @TenantId AND BusinessProfileId = @BusinessProfileId)
    BEGIN SELECT ResultCode = 1, ResultMessage = N'That series no longer exists'; RETURN; END

    IF @Separator NOT IN ('', '-', '/')
    BEGIN SELECT ResultCode = 5, ResultMessage = N'Use a hyphen, a slash, or nothing between the parts', FieldName = 'Separator'; RETURN; END

    IF @Suffix IS NOT NULL AND @Suffix LIKE '%[^A-Za-z0-9/-]%'
    BEGIN SELECT ResultCode = 5, ResultMessage = N'A suffix can hold letters, numbers, slashes and hyphens only', FieldName = 'Suffix'; RETURN; END

    /* Rule 46(b): at most 16 characters. Measured on the longest number this
       year can produce with the chosen padding. */
    DECLARE @sample NVARCHAR(40) = dbo.fn_FormatDocNumber(@Prefix, @Suffix, @Separator, @YearFormat,
                                       dbo.fn_FinancialYear(CAST(SYSUTCDATETIME() AS DATE)),
                                       CASE WHEN @StartFrom > POWER(CAST(10 AS BIGINT), @PadWidth) - 1 THEN @StartFrom
                                            ELSE CAST(POWER(CAST(10 AS BIGINT), @PadWidth) - 1 AS INT) END, @PadWidth);
    IF LEN(@sample) > 16
    BEGIN
        SELECT ResultCode = 5,
               ResultMessage = CONCAT(N'GST invoice numbers can be at most 16 characters; this format reaches ', LEN(@sample),
                                      N' (', @sample, N'). Shorten the prefix, drop a digit, or use a shorter year'),
               FieldName = 'Prefix';
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM dbo.tbl_NumberSeries
                WHERE TenantId = @TenantId AND DocumentType = @DocumentType AND IsActive = 1 AND SeriesId <> @SeriesId
                  AND ISNULL(Prefix, N'') = ISNULL(@Prefix, N'') AND ISNULL(Suffix, N'') = ISNULL(@Suffix, N'')
                  AND YearFormat = @YearFormat)
    BEGIN
        SELECT ResultCode = 5,
               ResultMessage = N'Another series already numbers this kind of document the same way. Give this one a different prefix so no two documents can share a number',
               FieldName = 'Prefix';
        RETURN;
    END

    DECLARE @r TABLE (ResultCode INT, ResultMessage NVARCHAR(400), FieldName VARCHAR(40) NULL, SeriesId BIGINT NULL);

    BEGIN TRY
        BEGIN TRANSACTION;

        /* The base procedure clears other defaults across the whole business;
           with profiles, only this profile's default for the type moves. */
        IF @IsDefault = 1
            UPDATE dbo.tbl_NumberSeries SET IsDefault = 0, UpdatedAtUtc = SYSUTCDATETIME(), UpdatedBy = @ActionByUserId
             WHERE TenantId = @TenantId AND BusinessProfileId = @BusinessProfileId AND DocumentType = @DocumentType
               AND IsDefault = 1 AND IsActive = 1 AND SeriesId <> @SeriesId;
        ELSE IF NOT EXISTS (SELECT 1 FROM dbo.tbl_NumberSeries WHERE TenantId = @TenantId AND BusinessProfileId = @BusinessProfileId
                               AND DocumentType = @DocumentType AND IsActive = 1 AND IsDefault = 1 AND SeriesId <> @SeriesId)
            SET @IsDefault = 1;

        DECLARE @now DATETIME2(3) = SYSUTCDATETIME();
        DECLARE @issued INT = (SELECT COUNT(*) FROM dbo.tbl_IssuedNumbers WHERE SeriesId = @SeriesId);

        IF @SeriesId > 0 AND @issued > 0 AND EXISTS
           (SELECT 1 FROM dbo.tbl_NumberSeries WHERE SeriesId = @SeriesId
               AND (ISNULL(Prefix, '') <> ISNULL(@Prefix, '') OR ISNULL(Suffix, '') <> ISNULL(@Suffix, '')
                    OR PadWidth <> @PadWidth OR YearFormat <> @YearFormat OR Separator <> @Separator
                    OR ResetYearly <> @ResetYearly))
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT ResultCode = 5,
                   ResultMessage = CONCAT(@issued, N' documents already carry this format. Changing it would break the consecutive run the GST rules require; add a new series instead (from 1 April is cleanest)'),
                   FieldName = 'Prefix';
            RETURN;
        END

        IF @SeriesId > 0
            UPDATE dbo.tbl_NumberSeries
               SET SeriesName = @SeriesName, Prefix = @Prefix, Suffix = @Suffix, Separator = @Separator,
                   PadWidth = @PadWidth, YearFormat = @YearFormat, ResetYearly = @ResetYearly,
                   StartFrom = CASE WHEN @issued = 0 THEN @StartFrom ELSE StartFrom END,
                   IsDefault = @IsDefault, UpdatedAtUtc = @now, UpdatedBy = @ActionByUserId
             WHERE SeriesId = @SeriesId AND TenantId = @TenantId;
        ELSE
        BEGIN
            INSERT INTO dbo.tbl_NumberSeries
                  (TenantId, BusinessProfileId, DocumentType, SeriesName, Prefix, Suffix, Separator, PadWidth,
                   YearFormat, ResetYearly, StartFrom, IsDefault, IsActive, CreatedAtUtc, CreatedBy)
            VALUES(@TenantId, @BusinessProfileId, @DocumentType, LTRIM(RTRIM(@SeriesName)), @Prefix, @Suffix, @Separator, @PadWidth,
                   @YearFormat, @ResetYearly, @StartFrom, @IsDefault, 1, @now, @ActionByUserId);
            SET @SeriesId = SCOPE_IDENTITY();
        END

        INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, IpAddress)
        VALUES(@TenantId, @ActionByUserId, 'Numbering.Saved', 'NumberSeries', @SeriesId, @SeriesName,
               CONCAT(@SeriesName, N': next number ', @sample), @IpAddress);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok', SeriesId = @SeriesId;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_NumberSeries_Retire
    @TenantId          BIGINT,
    @BusinessProfileId BIGINT,
    @SeriesId          BIGINT,
    @ActionByUserId    BIGINT,
    @IpAddress         VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @name NVARCHAR(60), @isDefault BIT;

    SELECT @name = SeriesName, @isDefault = IsDefault FROM dbo.tbl_NumberSeries
     WHERE SeriesId = @SeriesId AND TenantId = @TenantId AND BusinessProfileId = @BusinessProfileId AND IsActive = 1;

    IF @name IS NULL BEGIN SELECT ResultCode = 1, ResultMessage = N'That series no longer exists'; RETURN; END
    IF @isDefault = 1
    BEGIN SELECT ResultCode = 5, ResultMessage = N'Make another series the default first. Documents always need a series to draw from'; RETURN; END

    /* Retired, never deleted: the numbers it issued stay in the register. */
    UPDATE dbo.tbl_NumberSeries SET IsActive = 0, UpdatedAtUtc = SYSUTCDATETIME(), UpdatedBy = @ActionByUserId
     WHERE SeriesId = @SeriesId;

    INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, IpAddress)
    VALUES(@TenantId, @ActionByUserId, 'Numbering.Retired', 'NumberSeries', @SeriesId, @name, CONCAT(N'Retired ', @name), @IpAddress);

    SELECT ResultCode = 0, ResultMessage = N'Ok';
END
GO
