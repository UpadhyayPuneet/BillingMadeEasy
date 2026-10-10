/* 37 · Sales invoices
   ------------------------------------------------------------------
   A draft can change freely and has no number. Issuing takes the next number
   from the profile's series in the same transaction as the status change, so
   a number is never skipped or given twice, and freezes the invoice: the
   seller's details, the buyer's details and every amount are copied onto it,
   so changing a customer's address or your logo next year never rewrites an
   invoice already sent. Corrections after that are credit or debit notes;
   a mistake can be cancelled, and the number stays in the register.

   Amounts are computed by the application (BillingMadeEasy.Core InvoiceMath)
   and stored as printed.

   Safe to run more than once. */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('dbo.tbl_SalesInvoices') IS NULL
CREATE TABLE dbo.tbl_SalesInvoices
(
    SalesInvoiceId       BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_SalesInvoices PRIMARY KEY,
    TenantId             BIGINT          NOT NULL,
    PublicId             UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_SalesInvoices_PublicId DEFAULT (NEWID()),
    BusinessProfileId    BIGINT          NOT NULL,
    DocumentType         TINYINT         NOT NULL CONSTRAINT DF_SalesInvoices_DocType DEFAULT (1),   -- 1 tax invoice, 2 bill of supply
    Status               TINYINT         NOT NULL CONSTRAINT DF_SalesInvoices_Status DEFAULT (1),    -- 1 draft, 2 issued, 3 cancelled
    SeriesId             BIGINT          NULL,
    IssuedNumberId       BIGINT          NULL,
    InvoiceNumber        NVARCHAR(40)    NULL,
    InvoiceDate          DATE            NOT NULL,
    DueDate              DATE            NULL,

    PartyId              BIGINT          NULL,       -- null: a walk-in customer, name only
    PartyLocationId      BIGINT          NULL,
    BuyerName            NVARCHAR(200)   NOT NULL,
    BuyerGstin           VARCHAR(15)     NULL,
    BuyerAddress         NVARCHAR(500)   NULL,
    BuyerStateCode       VARCHAR(10)     NULL,
    BuyerPhone           VARCHAR(20)     NULL,
    BuyerEmail           NVARCHAR(150)   NULL,
    ShipToName           NVARCHAR(200)   NULL,
    ShipToAddress        NVARCHAR(500)   NULL,
    ShipToStateCode      VARCHAR(10)     NULL,

    PlaceOfSupply        VARCHAR(10)     NULL,
    IsInterState         BIT             NOT NULL CONSTRAINT DF_SalesInvoices_Inter DEFAULT (0),
    IsReverseCharge      BIT             NOT NULL CONSTRAINT DF_SalesInvoices_RCM DEFAULT (0),
    IsComposition        BIT             NOT NULL CONSTRAINT DF_SalesInvoices_Comp DEFAULT (0),
    RoundOffTotal        BIT             NOT NULL CONSTRAINT DF_SalesInvoices_Round DEFAULT (1),

    PoNumber             NVARCHAR(40)    NULL,
    PoDate               DATE            NULL,
    Notes                NVARCHAR(1000)  NULL,
    Terms                NVARCHAR(2000)  NULL,

    GrossTotal           DECIMAL(18,2)   NOT NULL CONSTRAINT DF_SalesInvoices_Gross DEFAULT (0),
    DiscountTotal        DECIMAL(18,2)   NOT NULL CONSTRAINT DF_SalesInvoices_Disc DEFAULT (0),
    TaxableTotal         DECIMAL(18,2)   NOT NULL CONSTRAINT DF_SalesInvoices_Taxable DEFAULT (0),
    CgstTotal            DECIMAL(18,2)   NOT NULL CONSTRAINT DF_SalesInvoices_Cgst DEFAULT (0),
    SgstTotal            DECIMAL(18,2)   NOT NULL CONSTRAINT DF_SalesInvoices_Sgst DEFAULT (0),
    IgstTotal            DECIMAL(18,2)   NOT NULL CONSTRAINT DF_SalesInvoices_Igst DEFAULT (0),
    ReimbursementTotal   DECIMAL(18,2)   NOT NULL CONSTRAINT DF_SalesInvoices_Reimb DEFAULT (0),
    RoundOff             DECIMAL(18,2)   NOT NULL CONSTRAINT DF_SalesInvoices_RoundOff DEFAULT (0),
    GrandTotal           DECIMAL(18,2)   NOT NULL CONSTRAINT DF_SalesInvoices_Grand DEFAULT (0),
    AmountPaid           DECIMAL(18,2)   NOT NULL CONSTRAINT DF_SalesInvoices_Paid DEFAULT (0),

    SellerSnapshot       NVARCHAR(MAX)   NULL,       -- the profile and bank account as printed, JSON
    IssuedAtUtc          DATETIME2(3)    NULL,
    IssuedBy             BIGINT          NULL,
    CancelledAtUtc       DATETIME2(3)    NULL,
    CancelledBy          BIGINT          NULL,
    CancelReason         NVARCHAR(200)   NULL,
    CreatedAtUtc         DATETIME2(3)    NOT NULL CONSTRAINT DF_SalesInvoices_Created DEFAULT (SYSUTCDATETIME()),
    CreatedBy            BIGINT          NULL,
    UpdatedAtUtc         DATETIME2(3)    NULL,
    UpdatedBy            BIGINT          NULL,
    RowVersion           ROWVERSION      NOT NULL,

    CONSTRAINT FK_SalesInvoices_Tenant  FOREIGN KEY (TenantId) REFERENCES dbo.tbl_Tenants (TenantId),
    CONSTRAINT FK_SalesInvoices_Profile FOREIGN KEY (BusinessProfileId) REFERENCES dbo.tbl_BusinessProfiles (BusinessProfileId),
    CONSTRAINT FK_SalesInvoices_Party   FOREIGN KEY (PartyId) REFERENCES dbo.tbl_Parties (PartyId),
    CONSTRAINT CK_SalesInvoices_Status  CHECK (Status IN (1, 2, 3)),
    CONSTRAINT CK_SalesInvoices_Number  CHECK (Status = 1 OR InvoiceNumber IS NOT NULL),
    CONSTRAINT CK_SalesInvoices_Due     CHECK (DueDate IS NULL OR DueDate >= InvoiceDate)
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SalesInvoices_List')
    CREATE INDEX IX_SalesInvoices_List ON dbo.tbl_SalesInvoices (TenantId, Status, InvoiceDate DESC)
        INCLUDE (InvoiceNumber, BuyerName, GrandTotal, AmountPaid, DueDate, PartyId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SalesInvoices_Party')
    CREATE INDEX IX_SalesInvoices_Party ON dbo.tbl_SalesInvoices (TenantId, PartyId, InvoiceDate DESC) WHERE PartyId IS NOT NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_SalesInvoices_Number')
    CREATE UNIQUE INDEX UX_SalesInvoices_Number ON dbo.tbl_SalesInvoices (TenantId, DocumentType, InvoiceNumber) WHERE InvoiceNumber IS NOT NULL;
GO

IF OBJECT_ID('dbo.tbl_SalesInvoiceLines') IS NULL
CREATE TABLE dbo.tbl_SalesInvoiceLines
(
    SalesInvoiceLineId   BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_SalesInvoiceLines PRIMARY KEY,
    SalesInvoiceId       BIGINT          NOT NULL,
    TenantId             BIGINT          NOT NULL,
    LineNumber               SMALLINT        NOT NULL,
    OfferingId           BIGINT          NULL,
    Description          NVARCHAR(300)   NOT NULL,
    Details              NVARCHAR(1000)  NULL,
    HsnSacCode           VARCHAR(10)     NULL,
    Quantity             DECIMAL(18,4)   NOT NULL,
    UnitCode             NVARCHAR(20)    NULL,
    UqcCode              VARCHAR(10)     NULL,
    Rate                 DECIMAL(18,4)   NOT NULL,
    RateIncludesTax      BIT             NOT NULL CONSTRAINT DF_SalesInvoiceLines_Incl DEFAULT (0),
    DiscountPercent      DECIMAL(9,4)    NOT NULL CONSTRAINT DF_SalesInvoiceLines_DiscPct DEFAULT (0),
    GrossAmount          DECIMAL(18,2)   NOT NULL,
    DiscountAmount       DECIMAL(18,2)   NOT NULL,
    TaxableValue         DECIMAL(18,2)   NOT NULL,
    TaxRateId            BIGINT          NULL,
    TaxRatePercent       DECIMAL(7,4)    NOT NULL,
    CgstAmount           DECIMAL(18,2)   NOT NULL,
    SgstAmount           DECIMAL(18,2)   NOT NULL,
    IgstAmount           DECIMAL(18,2)   NOT NULL,
    LineTotal            DECIMAL(18,2)   NOT NULL,
    IsPureAgent          BIT             NOT NULL CONSTRAINT DF_SalesInvoiceLines_PA DEFAULT (0),
    PriceSource          NVARCHAR(80)    NULL,       -- "Standard price", "Agreed price · FreshBite", "Entered"
    CONSTRAINT FK_SalesInvoiceLines_Invoice FOREIGN KEY (SalesInvoiceId) REFERENCES dbo.tbl_SalesInvoices (SalesInvoiceId) ON DELETE CASCADE,
    CONSTRAINT FK_SalesInvoiceLines_Offering FOREIGN KEY (OfferingId) REFERENCES dbo.tbl_Offerings (OfferingId),
    CONSTRAINT CK_SalesInvoiceLines_Qty CHECK (Quantity > 0),
    CONSTRAINT CK_SalesInvoiceLines_Rate CHECK (Rate >= 0)
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SalesInvoiceLines_Invoice')
    CREATE INDEX IX_SalesInvoiceLines_Invoice ON dbo.tbl_SalesInvoiceLines (SalesInvoiceId, LineNumber);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SalesInvoiceLines_Offering')
    CREATE INDEX IX_SalesInvoiceLines_Offering ON dbo.tbl_SalesInvoiceLines (TenantId, OfferingId) INCLUDE (Rate, Quantity) WHERE OfferingId IS NOT NULL;
GO

/* ============================================================================
   SAVE A DRAFT

   Header fields plus @Lines as JSON. The lines are replaced as a whole: a
   draft is one thing being edited, not a set of rows edited separately.
   ========================================================================= */
CREATE OR ALTER PROCEDURE dbo.usp_SalesInvoice_Save
    @TenantId           BIGINT,
    @SalesInvoiceId     BIGINT = 0,
    @BusinessProfileId  BIGINT,
    @DocumentType       TINYINT = 1,
    @InvoiceDate        DATE,
    @DueDate            DATE = NULL,
    @PartyId            BIGINT = NULL,
    @PartyLocationId    BIGINT = NULL,
    @BuyerName          NVARCHAR(200),
    @BuyerGstin         VARCHAR(15) = NULL,
    @BuyerAddress       NVARCHAR(500) = NULL,
    @BuyerStateCode     VARCHAR(10) = NULL,
    @BuyerPhone         VARCHAR(20) = NULL,
    @BuyerEmail         NVARCHAR(150) = NULL,
    @ShipToName         NVARCHAR(200) = NULL,
    @ShipToAddress      NVARCHAR(500) = NULL,
    @ShipToStateCode    VARCHAR(10) = NULL,
    @PlaceOfSupply      VARCHAR(10) = NULL,
    @IsInterState       BIT = 0,
    @IsReverseCharge    BIT = 0,
    @IsComposition      BIT = 0,
    @RoundOffTotal      BIT = 1,
    @PoNumber           NVARCHAR(40) = NULL,
    @PoDate             DATE = NULL,
    @Notes              NVARCHAR(1000) = NULL,
    @Terms              NVARCHAR(2000) = NULL,
    @GrossTotal         DECIMAL(18,2),
    @DiscountTotal      DECIMAL(18,2),
    @TaxableTotal       DECIMAL(18,2),
    @CgstTotal          DECIMAL(18,2),
    @SgstTotal          DECIMAL(18,2),
    @IgstTotal          DECIMAL(18,2),
    @ReimbursementTotal DECIMAL(18,2),
    @RoundOff           DECIMAL(18,2),
    @GrandTotal         DECIMAL(18,2),
    @Lines              NVARCHAR(MAX),
    @ActionByUserId     BIGINT,
    @IpAddress          VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @isNew BIT = CASE WHEN @SalesInvoiceId > 0 THEN 0 ELSE 1 END;
    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();

    IF NOT EXISTS (SELECT 1 FROM dbo.tbl_BusinessProfiles WHERE BusinessProfileId = @BusinessProfileId AND TenantId = @TenantId AND IsActive = 1)
    BEGIN SELECT ResultCode = 5, ResultMessage = N'Choose which of your businesses this invoice is from', FieldName = 'BusinessProfileId'; RETURN; END

    IF @PartyId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.tbl_Parties WHERE PartyId = @PartyId AND TenantId = @TenantId)
    BEGIN SELECT ResultCode = 5, ResultMessage = N'That customer no longer exists', FieldName = 'PartyId'; RETURN; END

    IF @PartyLocationId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.tbl_PartyLocations WHERE PartyLocationId = @PartyLocationId AND PartyId = @PartyId AND TenantId = @TenantId)
        SET @PartyLocationId = NULL;

    IF LEN(LTRIM(RTRIM(ISNULL(@BuyerName, '')))) < 2
    BEGIN SELECT ResultCode = 5, ResultMessage = N'Choose a customer or enter a name', FieldName = 'PartyId'; RETURN; END

    /* Every item on the invoice must belong to this business. */
    IF EXISTS (SELECT 1 FROM OPENJSON(@Lines) WITH (OfferingId BIGINT) j
                WHERE j.OfferingId IS NOT NULL
                  AND NOT EXISTS (SELECT 1 FROM dbo.tbl_Offerings o WHERE o.OfferingId = j.OfferingId AND o.TenantId = @TenantId))
    BEGIN SELECT ResultCode = 5, ResultMessage = N'An item on this invoice no longer exists'; RETURN; END

    BEGIN TRY
        DECLARE @own BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
        IF @own = 1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION sp_invoice_save;

        IF @isNew = 1
        BEGIN
            INSERT INTO dbo.tbl_SalesInvoices
                  (TenantId, BusinessProfileId, DocumentType, Status, InvoiceDate, DueDate, PartyId, PartyLocationId,
                   BuyerName, BuyerGstin, BuyerAddress, BuyerStateCode, BuyerPhone, BuyerEmail,
                   ShipToName, ShipToAddress, ShipToStateCode, PlaceOfSupply, IsInterState, IsReverseCharge, IsComposition, RoundOffTotal,
                   PoNumber, PoDate, Notes, Terms,
                   GrossTotal, DiscountTotal, TaxableTotal, CgstTotal, SgstTotal, IgstTotal, ReimbursementTotal, RoundOff, GrandTotal,
                   CreatedBy)
            VALUES(@TenantId, @BusinessProfileId, @DocumentType, 1, @InvoiceDate, @DueDate, @PartyId, @PartyLocationId,
                   LTRIM(RTRIM(@BuyerName)), @BuyerGstin, @BuyerAddress, @BuyerStateCode, @BuyerPhone, @BuyerEmail,
                   @ShipToName, @ShipToAddress, @ShipToStateCode, @PlaceOfSupply, @IsInterState, @IsReverseCharge, @IsComposition, @RoundOffTotal,
                   @PoNumber, @PoDate, @Notes, @Terms,
                   @GrossTotal, @DiscountTotal, @TaxableTotal, @CgstTotal, @SgstTotal, @IgstTotal, @ReimbursementTotal, @RoundOff, @GrandTotal,
                   @ActionByUserId);
            SET @SalesInvoiceId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            DECLARE @status TINYINT;
            SELECT @status = Status FROM dbo.tbl_SalesInvoices WITH (UPDLOCK)
             WHERE SalesInvoiceId = @SalesInvoiceId AND TenantId = @TenantId;

            IF @status IS NULL
            BEGIN IF @own = 1 ROLLBACK TRANSACTION; ELSE ROLLBACK TRANSACTION sp_invoice_save; SELECT ResultCode = 1, ResultMessage = N'That invoice no longer exists'; RETURN; END
            IF @status <> 1
            BEGIN IF @own = 1 ROLLBACK TRANSACTION; ELSE ROLLBACK TRANSACTION sp_invoice_save; SELECT ResultCode = 5, ResultMessage = N'This invoice has been issued, so it can''t be edited. Raise a credit or debit note to correct it'; RETURN; END

            UPDATE dbo.tbl_SalesInvoices
               SET BusinessProfileId = @BusinessProfileId, DocumentType = @DocumentType, InvoiceDate = @InvoiceDate, DueDate = @DueDate,
                   PartyId = @PartyId, PartyLocationId = @PartyLocationId, BuyerName = LTRIM(RTRIM(@BuyerName)), BuyerGstin = @BuyerGstin,
                   BuyerAddress = @BuyerAddress, BuyerStateCode = @BuyerStateCode, BuyerPhone = @BuyerPhone, BuyerEmail = @BuyerEmail,
                   ShipToName = @ShipToName, ShipToAddress = @ShipToAddress, ShipToStateCode = @ShipToStateCode,
                   PlaceOfSupply = @PlaceOfSupply, IsInterState = @IsInterState, IsReverseCharge = @IsReverseCharge,
                   IsComposition = @IsComposition, RoundOffTotal = @RoundOffTotal, PoNumber = @PoNumber, PoDate = @PoDate,
                   Notes = @Notes, Terms = @Terms,
                   GrossTotal = @GrossTotal, DiscountTotal = @DiscountTotal, TaxableTotal = @TaxableTotal, CgstTotal = @CgstTotal,
                   SgstTotal = @SgstTotal, IgstTotal = @IgstTotal, ReimbursementTotal = @ReimbursementTotal, RoundOff = @RoundOff,
                   GrandTotal = @GrandTotal, UpdatedAtUtc = @now, UpdatedBy = @ActionByUserId
             WHERE SalesInvoiceId = @SalesInvoiceId;

            DELETE FROM dbo.tbl_SalesInvoiceLines WHERE SalesInvoiceId = @SalesInvoiceId;
        END

        INSERT INTO dbo.tbl_SalesInvoiceLines
              (SalesInvoiceId, TenantId, LineNumber, OfferingId, Description, Details, HsnSacCode, Quantity, UnitCode, UqcCode,
               Rate, RateIncludesTax, DiscountPercent, GrossAmount, DiscountAmount, TaxableValue, TaxRateId, TaxRatePercent,
               CgstAmount, SgstAmount, IgstAmount, LineTotal, IsPureAgent, PriceSource)
        SELECT @SalesInvoiceId, @TenantId, j.LineNumber, j.OfferingId, j.Description, j.Details, j.HsnSacCode, j.Quantity, j.UnitCode, j.UqcCode,
               j.Rate, j.RateIncludesTax, j.DiscountPercent, j.GrossAmount, j.DiscountAmount, j.TaxableValue, j.TaxRateId, j.TaxRatePercent,
               j.CgstAmount, j.SgstAmount, j.IgstAmount, j.LineTotal, j.IsPureAgent, j.PriceSource
          FROM OPENJSON(@Lines) WITH (
               LineNumber SMALLINT, OfferingId BIGINT, Description NVARCHAR(300), Details NVARCHAR(1000), HsnSacCode VARCHAR(10),
               Quantity DECIMAL(18,4), UnitCode NVARCHAR(20), UqcCode VARCHAR(10), Rate DECIMAL(18,4), RateIncludesTax BIT,
               DiscountPercent DECIMAL(9,4), GrossAmount DECIMAL(18,2), DiscountAmount DECIMAL(18,2), TaxableValue DECIMAL(18,2),
               TaxRateId BIGINT, TaxRatePercent DECIMAL(7,4), CgstAmount DECIMAL(18,2), SgstAmount DECIMAL(18,2),
               IgstAmount DECIMAL(18,2), LineTotal DECIMAL(18,2), IsPureAgent BIT, PriceSource NVARCHAR(80)) j;

        IF @isNew = 1
            INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, IpAddress)
            VALUES(@TenantId, @ActionByUserId, 'Invoice.DraftCreated', 'SalesInvoice', @SalesInvoiceId, @BuyerName,
                   CONCAT(N'Draft invoice for ', @BuyerName), @IpAddress);

        IF @own = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @own = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok', SalesInvoiceId = @SalesInvoiceId, IsNew = @isNew;
END
GO

/* ============================================================================
   ISSUE

   The number and the status change commit together or not at all. The seller's
   details are frozen onto the invoice at this moment.
   ========================================================================= */
CREATE OR ALTER PROCEDURE dbo.usp_SalesInvoice_Issue
    @TenantId       BIGINT,
    @SalesInvoiceId BIGINT,
    @SellerSnapshot NVARCHAR(MAX),
    @Today          DATE,             -- in India, from the application
    @MonthlyLimit   INT = NULL,       -- the plan's invoices a month; null is unlimited
    @ActionByUserId BIGINT,
    @IpAddress      VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @status TINYINT, @profileId BIGINT, @docType TINYINT, @date DATE, @partyId BIGINT, @buyer NVARCHAR(200);
    DECLARE @lines INT, @grand DECIMAL(18,2), @seriesId BIGINT;

    BEGIN TRY
        DECLARE @own BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
        IF @own = 1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION sp_invoice_issue;

        SELECT @status = Status, @profileId = BusinessProfileId, @docType = DocumentType, @date = InvoiceDate,
               @partyId = PartyId, @buyer = BuyerName, @grand = GrandTotal
          FROM dbo.tbl_SalesInvoices WITH (UPDLOCK, HOLDLOCK)
         WHERE SalesInvoiceId = @SalesInvoiceId AND TenantId = @TenantId;

        SELECT @lines = COUNT(*) FROM dbo.tbl_SalesInvoiceLines WHERE SalesInvoiceId = @SalesInvoiceId;

        DECLARE @problem NVARCHAR(300) =
            CASE WHEN @status IS NULL THEN N'That invoice no longer exists'
                 WHEN @status = 2 THEN N'This invoice is already issued'
                 WHEN @status = 3 THEN N'This invoice was cancelled'
                 WHEN @lines = 0 THEN N'Add at least one line before issuing'
                 WHEN @grand <= 0 THEN N'The total is zero. Check quantities and rates'
                 WHEN @date > @Today THEN N'An invoice can''t be dated in the future'
                 WHEN @partyId IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.tbl_Parties WHERE PartyId = @partyId AND (Status <> 1 OR IsActive = 0))
                      THEN N'This customer is on hold or closed. Make them active before invoicing'
                 /* Counted inside the lock, so two people issuing together can't both pass it. */
                 WHEN @MonthlyLimit IS NOT NULL AND
                      (SELECT COUNT(*) FROM dbo.tbl_SalesInvoices WITH (UPDLOCK)
                        WHERE TenantId = @TenantId AND Status IN (2, 3)
                          AND IssuedAtUtc >= DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1)) >= @MonthlyLimit
                      THEN CONCAT(N'Your plan includes ', @MonthlyLimit, N' invoices a month and all are used. Upgrade under Plan & modules to keep invoicing; this draft is saved')
            END;
        IF @problem IS NOT NULL
        BEGIN IF @own = 1 ROLLBACK TRANSACTION; ELSE ROLLBACK TRANSACTION sp_invoice_issue; SELECT ResultCode = 5, ResultMessage = @problem; RETURN; END

        SELECT @seriesId = SeriesId FROM dbo.tbl_NumberSeries
         WHERE TenantId = @TenantId AND BusinessProfileId = @profileId AND DocumentType = @docType AND IsDefault = 1 AND IsActive = 1;

        /* A bill of supply needs its own run. The first one creates it. */
        IF @seriesId IS NULL AND @docType = 2
        BEGIN
            DECLARE @prefix NVARCHAR(15) = N'BOS', @n INT = 2;
            WHILE EXISTS (SELECT 1 FROM dbo.tbl_NumberSeries WHERE TenantId = @TenantId AND DocumentType = 2 AND IsActive = 1 AND Prefix = @prefix)
            BEGIN SET @prefix = CONCAT(N'BOS', @n); SET @n += 1; END
            INSERT INTO dbo.tbl_NumberSeries (TenantId, BusinessProfileId, DocumentType, SeriesName, Prefix, PadWidth, Separator,
                                              YearFormat, ResetYearly, StartFrom, IsDefault, IsActive, CreatedAtUtc, CreatedBy)
            VALUES(@TenantId, @profileId, 2, N'Bills of supply', @prefix, 4, N'-', 2, 1, 1, 1, 1, SYSUTCDATETIME(), @ActionByUserId);
            SET @seriesId = SCOPE_IDENTITY();
        END

        IF @seriesId IS NULL
        BEGIN IF @own = 1 ROLLBACK TRANSACTION; ELSE ROLLBACK TRANSACTION sp_invoice_issue; SELECT ResultCode = 5, ResultMessage = N'No numbering series is set up for this business. Add one under Your business'; RETURN; END

        DECLARE @issued TABLE (ResultCode INT, ResultMessage NVARCHAR(400), IssuedNumberId BIGINT, FullNumber NVARCHAR(40),
                               SequenceNumber INT, FinancialYear SMALLINT, SeriesId BIGINT);
        INSERT INTO @issued
        EXEC dbo.usp_Number_Issue @TenantId = @TenantId, @DocumentType = @docType, @DocumentDate = @date,
                                  @SeriesId = @seriesId, @DocumentId = @SalesInvoiceId, @IssuedBy = @ActionByUserId;

        DECLARE @number NVARCHAR(40), @numberId BIGINT;
        SELECT @number = FullNumber, @numberId = IssuedNumberId FROM @issued WHERE ResultCode = 0;

        IF @number IS NULL
        BEGIN IF @own = 1 ROLLBACK TRANSACTION; ELSE ROLLBACK TRANSACTION sp_invoice_issue; SELECT ResultCode = 5, ResultMessage = ISNULL((SELECT TOP (1) ResultMessage FROM @issued), N'No number could be issued'); RETURN; END

        UPDATE dbo.tbl_SalesInvoices
           SET Status = 2, SeriesId = @seriesId, IssuedNumberId = @numberId, InvoiceNumber = @number,
               SellerSnapshot = @SellerSnapshot, IssuedAtUtc = SYSUTCDATETIME(), IssuedBy = @ActionByUserId,
               UpdatedAtUtc = SYSUTCDATETIME(), UpdatedBy = @ActionByUserId
         WHERE SalesInvoiceId = @SalesInvoiceId;

        INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, IpAddress)
        VALUES(@TenantId, @ActionByUserId, 'Invoice.Issued', 'SalesInvoice', @SalesInvoiceId, @number,
               CONCAT(N'Issued ', @number, N' to ', @buyer, N' for ₹', FORMAT(@grand, 'N2', 'en-IN')), @IpAddress);

        IF @own = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @own = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok', InvoiceNumber = @number;
END
GO

/* Cancel an issued invoice (its number stays in the register), or discard a draft. */
CREATE OR ALTER PROCEDURE dbo.usp_SalesInvoice_Cancel
    @TenantId       BIGINT,
    @SalesInvoiceId BIGINT,
    @Reason         NVARCHAR(200) = NULL,
    @ActionByUserId BIGINT,
    @IpAddress      VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @status TINYINT, @number NVARCHAR(40), @buyer NVARCHAR(200), @docType TINYINT, @paid DECIMAL(18,2);

    SELECT @status = Status, @number = InvoiceNumber, @buyer = BuyerName, @docType = DocumentType, @paid = AmountPaid
      FROM dbo.tbl_SalesInvoices WHERE SalesInvoiceId = @SalesInvoiceId AND TenantId = @TenantId;

    IF @status IS NULL BEGIN SELECT ResultCode = 1, ResultMessage = N'That invoice no longer exists', Discarded = CONVERT(BIT, 0); RETURN; END
    IF @status = 3 BEGIN SELECT ResultCode = 5, ResultMessage = N'This invoice is already cancelled', Discarded = CONVERT(BIT, 0); RETURN; END

    BEGIN TRY
        DECLARE @own BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
        IF @own = 1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION sp_invoice_cancel;

        IF @status = 1
        BEGIN
            /* A draft never had a number; it simply goes. */
            DELETE FROM dbo.tbl_SalesInvoices WHERE SalesInvoiceId = @SalesInvoiceId;
            INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, IpAddress)
            VALUES(@TenantId, @ActionByUserId, 'Invoice.DraftDiscarded', 'SalesInvoice', @SalesInvoiceId, @buyer,
                   CONCAT(N'Discarded draft for ', @buyer), @IpAddress);
            IF @own = 1 COMMIT TRANSACTION;
            SELECT ResultCode = 0, ResultMessage = N'Ok', Discarded = CONVERT(BIT, 1);
            RETURN;
        END

        IF @paid > 0
        BEGIN
            IF @own = 1 ROLLBACK TRANSACTION; ELSE ROLLBACK TRANSACTION sp_invoice_cancel;
            SELECT ResultCode = 5, ResultMessage = N'Payments are recorded against this invoice. Reverse them first, or raise a credit note instead', Discarded = CONVERT(BIT, 0);
            RETURN;
        END

        IF LEN(LTRIM(RTRIM(ISNULL(@Reason, '')))) < 3
        BEGIN
            IF @own = 1 ROLLBACK TRANSACTION; ELSE ROLLBACK TRANSACTION sp_invoice_cancel;
            SELECT ResultCode = 5, ResultMessage = N'Say why it is being cancelled. The reason stays on record', Discarded = CONVERT(BIT, 0);
            RETURN;
        END

        UPDATE dbo.tbl_SalesInvoices
           SET Status = 3, CancelledAtUtc = SYSUTCDATETIME(), CancelledBy = @ActionByUserId, CancelReason = LTRIM(RTRIM(@Reason)),
               UpdatedAtUtc = SYSUTCDATETIME(), UpdatedBy = @ActionByUserId
         WHERE SalesInvoiceId = @SalesInvoiceId;

        DECLARE @r TABLE (ResultCode INT, ResultMessage NVARCHAR(400), FullNumber NVARCHAR(40));
        INSERT INTO @r EXEC dbo.usp_Number_Cancel @TenantId = @TenantId, @DocumentType = @docType, @DocumentId = @SalesInvoiceId,
                                                  @Reason = @Reason, @ActionByUserId = @ActionByUserId;

        INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, IpAddress)
        VALUES(@TenantId, @ActionByUserId, 'Invoice.Cancelled', 'SalesInvoice', @SalesInvoiceId, @number,
               CONCAT(N'Cancelled ', @number, N': ', @Reason), @IpAddress);

        IF @own = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @own = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok', Discarded = CONVERT(BIT, 0);
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_SalesInvoice_Get
    @TenantId       BIGINT,
    @SalesInvoiceId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT i.*, PlaceOfSupplyName = s.StateName, ProfileName = p.ProfileName,
           CreatedByName = cu.FullName, IssuedByName = iu.FullName, CancelledByName = xu.FullName
      FROM dbo.tbl_SalesInvoices i
      LEFT JOIN dbo.tbl_StateCodes s ON s.CountryCode = 'IN' AND s.StateCode = i.PlaceOfSupply
      LEFT JOIN dbo.tbl_BusinessProfiles p ON p.BusinessProfileId = i.BusinessProfileId
      LEFT JOIN dbo.tbl_Users cu ON cu.UserId = i.CreatedBy
      LEFT JOIN dbo.tbl_Users iu ON iu.UserId = i.IssuedBy
      LEFT JOIN dbo.tbl_Users xu ON xu.UserId = i.CancelledBy
     WHERE i.SalesInvoiceId = @SalesInvoiceId AND i.TenantId = @TenantId;

    SELECT l.*
      FROM dbo.tbl_SalesInvoiceLines l
      JOIN dbo.tbl_SalesInvoices i ON i.SalesInvoiceId = l.SalesInvoiceId
     WHERE l.SalesInvoiceId = @SalesInvoiceId AND i.TenantId = @TenantId
     ORDER BY l.LineNumber;
END
GO

/* @View: 'all', 'draft', 'unpaid', 'overdue', 'paid', 'cancelled'. Totals for the strip above the list. */
CREATE OR ALTER PROCEDURE dbo.usp_SalesInvoice_List
    @TenantId BIGINT,
    @View     VARCHAR(12) = 'all',
    @Search   NVARCHAR(100) = NULL,
    @PartyId  BIGINT = NULL,
    @Today    DATE,
    @Page     INT = 1,
    @PageSize INT = 50
AS
BEGIN
    SET NOCOUNT ON;

    SET @Search = NULLIF(LTRIM(RTRIM(ISNULL(@Search, ''))), '');
    DECLARE @like NVARCHAR(110) = CONCAT(N'%', @Search, N'%');

    ;WITH v AS
    (
        SELECT i.SalesInvoiceId, i.Status, i.DocumentType, i.InvoiceNumber, i.InvoiceDate, i.DueDate, i.PartyId, i.BuyerName,
               i.BuyerGstin, i.GrandTotal, i.AmountPaid, Balance = i.GrandTotal - i.AmountPaid,
               IsOverdue = CONVERT(BIT, CASE WHEN i.Status = 2 AND i.GrandTotal > i.AmountPaid AND i.DueDate < @Today THEN 1 ELSE 0 END),
               DaysOverdue = CASE WHEN i.Status = 2 AND i.GrandTotal > i.AmountPaid AND i.DueDate < @Today THEN DATEDIFF(DAY, i.DueDate, @Today) END,
               i.CreatedAtUtc, i.UpdatedAtUtc
          FROM dbo.tbl_SalesInvoices i
         WHERE i.TenantId = @TenantId
           AND (@PartyId IS NULL OR i.PartyId = @PartyId)
           AND (@Search IS NULL OR i.InvoiceNumber LIKE @like OR i.BuyerName LIKE @like OR i.BuyerGstin LIKE @like OR i.PoNumber LIKE @like
                OR EXISTS (SELECT 1 FROM dbo.tbl_SalesInvoiceLines l WHERE l.SalesInvoiceId = i.SalesInvoiceId AND l.Description LIKE @like))
    )
    SELECT *, Total = COUNT(*) OVER ()
      FROM v
     WHERE @View = 'all'
        OR (@View = 'draft' AND Status = 1)
        OR (@View = 'unpaid' AND Status = 2 AND Balance > 0)
        OR (@View = 'overdue' AND IsOverdue = 1)
        OR (@View = 'paid' AND Status = 2 AND Balance <= 0)
        OR (@View = 'cancelled' AND Status = 3)
     ORDER BY CASE WHEN Status = 1 THEN 0 ELSE 1 END, InvoiceDate DESC, SalesInvoiceId DESC
    OFFSET (@Page - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT Drafts = SUM(CASE WHEN Status = 1 THEN 1 ELSE 0 END),
           Outstanding = ISNULL(SUM(CASE WHEN Status = 2 THEN GrandTotal - AmountPaid END), 0),
           OutstandingCount = SUM(CASE WHEN Status = 2 AND GrandTotal > AmountPaid THEN 1 ELSE 0 END),
           Overdue = ISNULL(SUM(CASE WHEN Status = 2 AND GrandTotal > AmountPaid AND DueDate < @Today THEN GrandTotal - AmountPaid END), 0),
           OverdueCount = SUM(CASE WHEN Status = 2 AND GrandTotal > AmountPaid AND DueDate < @Today THEN 1 ELSE 0 END),
           InvoicedThisMonth = ISNULL(SUM(CASE WHEN Status = 2 AND InvoiceDate >= DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1) THEN GrandTotal END), 0)
      FROM dbo.tbl_SalesInvoices
     WHERE TenantId = @TenantId AND (@PartyId IS NULL OR PartyId = @PartyId);
END
GO

/* What the item sells for to this customer: their agreed price, else the
   standard one, plus what they paid last time. */
CREATE OR ALTER PROCEDURE dbo.usp_SalesInvoice_ItemFor
    @TenantId   BIGINT,
    @OfferingId BIGINT,
    @PartyId    BIGINT = NULL,
    @Quantity   DECIMAL(18,4) = 1,
    @AsOnDate   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.tbl_Offerings WHERE OfferingId = @OfferingId AND TenantId = @TenantId)
    BEGIN SELECT ResultCode = 1, ResultMessage = N'That item no longer exists'; RETURN; END

    DECLARE @resolved TABLE (ResultCode INT, ResultMessage NVARCHAR(400), Price DECIMAL(18,4), DefaultPrice DECIMAL(18,4),
        Source NVARCHAR(40), PriceListName NVARCHAR(80), DiscountPercent DECIMAL(9,4), TaxRateId BIGINT, IsPriceInclusive BIT,
        UnitId BIGINT, HasPrice BIT, LastSoldPrice DECIMAL(18,4), LastSoldOn DATE, LastSoldQty DECIMAL(18,4), LastInvoiceNo NVARCHAR(40));

    INSERT INTO @resolved EXEC dbo.usp_Price_Resolve @TenantId = @TenantId, @OfferingId = @OfferingId, @PartyId = @PartyId,
                                                     @Quantity = @Quantity, @AsOnDate = @AsOnDate;

    SELECT TOP (1)
           r.ResultCode, r.ResultMessage, r.Price, r.DefaultPrice, r.Source, r.PriceListName, r.IsPriceInclusive,
           o.OfferingId, o.OfferingName, o.Description, o.HsnSacCode, o.IsPureAgent, o.OfferingType,
           o.TaxRateId, TaxRatePercent = ISNULL(t.RatePercent, 0), t.TaxName,
           u.UnitCode, u.UqcCode,
           LastSoldPrice = last.Rate, LastSoldOn = last.InvoiceDate, LastSoldQty = last.Quantity, LastInvoiceNo = last.InvoiceNumber
      FROM @resolved r
     CROSS JOIN dbo.tbl_Offerings o
      LEFT JOIN dbo.tbl_TaxRates t ON t.TaxRateId = o.TaxRateId
      LEFT JOIN dbo.tbl_Units u ON u.UnitId = o.UnitId
     OUTER APPLY (SELECT TOP (1) l.Rate, l.Quantity, i.InvoiceDate, i.InvoiceNumber
                    FROM dbo.tbl_SalesInvoiceLines l
                    JOIN dbo.tbl_SalesInvoices i ON i.SalesInvoiceId = l.SalesInvoiceId
                   WHERE i.TenantId = @TenantId AND i.Status = 2 AND i.PartyId = @PartyId AND l.OfferingId = @OfferingId
                   ORDER BY i.InvoiceDate DESC, i.SalesInvoiceId DESC) last
     WHERE o.OfferingId = @OfferingId AND o.TenantId = @TenantId;
END
GO

/* Items for the invoice line picker: what's sellable, best matches first. */
CREATE OR ALTER PROCEDURE dbo.usp_SalesInvoice_FindItems
    @TenantId BIGINT,
    @Search   NVARCHAR(100) = NULL,
    @PartyId  BIGINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @Search = NULLIF(LTRIM(RTRIM(ISNULL(@Search, ''))), '');
    DECLARE @like NVARCHAR(110) = CONCAT(N'%', @Search, N'%'), @starts NVARCHAR(110) = CONCAT(@Search, N'%');

    SELECT TOP (12) o.OfferingId, o.OfferingName, o.OfferingCode, o.HsnSacCode, o.DefaultPrice, o.IsPriceInclusive, u.UnitCode,
           t.TaxName, BrandName = b.BrandName,
           BoughtBefore = CONVERT(BIT, CASE WHEN @PartyId IS NOT NULL AND EXISTS (
                SELECT 1 FROM dbo.tbl_SalesInvoiceLines l JOIN dbo.tbl_SalesInvoices i ON i.SalesInvoiceId = l.SalesInvoiceId
                 WHERE i.TenantId = @TenantId AND i.PartyId = @PartyId AND i.Status = 2 AND l.OfferingId = o.OfferingId) THEN 1 ELSE 0 END)
      FROM dbo.tbl_Offerings o
      LEFT JOIN dbo.tbl_Units u ON u.UnitId = o.UnitId
      LEFT JOIN dbo.tbl_TaxRates t ON t.TaxRateId = o.TaxRateId
      LEFT JOIN dbo.tbl_ProductBrands b ON b.ProductBrandId = o.ProductBrandId
      LEFT JOIN dbo.tbl_ProductDetails d ON d.OfferingId = o.OfferingId
     WHERE o.TenantId = @TenantId AND o.IsActive = 1 AND o.IsSellable = 1
       AND (@Search IS NULL OR o.OfferingName LIKE @like OR o.OfferingCode LIKE @starts OR o.HsnSacCode LIKE @starts
            OR d.Barcode = @Search OR b.BrandName LIKE @starts)
     ORDER BY CASE WHEN d.Barcode = @Search OR o.OfferingCode = @Search THEN 0
                   WHEN o.OfferingName LIKE @starts THEN 1 ELSE 2 END,
              CASE WHEN @PartyId IS NOT NULL AND EXISTS (
                SELECT 1 FROM dbo.tbl_SalesInvoiceLines l JOIN dbo.tbl_SalesInvoices i ON i.SalesInvoiceId = l.SalesInvoiceId
                 WHERE i.TenantId = @TenantId AND i.PartyId = @PartyId AND i.Status = 2 AND l.OfferingId = o.OfferingId) THEN 0 ELSE 1 END,
              o.OfferingName;
END
GO

/* Place of supply for exports: GST code 96, "Other countries". */
IF NOT EXISTS (SELECT 1 FROM dbo.tbl_StateCodes WHERE CountryCode = 'IN' AND StateCode = '96')
    INSERT INTO dbo.tbl_StateCodes (StateCode, CountryCode, StateName, IsUnionTerritory, IsActive)
    VALUES ('96', 'IN', N'Other countries (export)', 0, 1);
GO
