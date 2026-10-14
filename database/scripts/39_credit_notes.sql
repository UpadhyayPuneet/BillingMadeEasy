/* 39 · Credit notes
   ------------------------------------------------------------------
   An issued invoice is never edited. When goods come back, a discount is
   passed on after the sale, or the invoice charged too much, a credit note
   (GST s.34) takes the value — and the tax on it — back.

   A credit note always points at the invoice it corrects and can't take back
   more than that invoice had, line by line: quantity and value are checked
   against everything credited on that line before, under a lock on the
   invoice, so two people can't credit the same goods twice.

   Its value first reduces what is still owed on that invoice. Whatever is
   left (the invoice was already paid) is the customer's credit: apply it to
   their other invoices, or refund it.

   tbl_SalesInvoices.AmountPaid stays "settled so far"; CreditedAmount says
   how much of that came from credit notes, as TdsDeducted does for TDS. So
   every balance (GrandTotal - AmountPaid) already counts credit notes.

   Safe to run more than once. */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF COL_LENGTH('dbo.tbl_SalesInvoices', 'CreditedAmount') IS NULL
    ALTER TABLE dbo.tbl_SalesInvoices ADD CreditedAmount DECIMAL(18,2) NOT NULL CONSTRAINT DF_SalesInvoices_Credited DEFAULT (0);
GO

IF OBJECT_ID('dbo.tbl_CreditNotes') IS NULL
CREATE TABLE dbo.tbl_CreditNotes
(
    CreditNoteId       BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_CreditNotes PRIMARY KEY,
    TenantId           BIGINT          NOT NULL,
    PublicId           UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_CreditNotes_PublicId DEFAULT (NEWID()),
    BusinessProfileId  BIGINT          NOT NULL,
    SalesInvoiceId     BIGINT          NOT NULL,          -- the invoice it corrects
    PartyId            BIGINT          NULL,
    SeriesId           BIGINT          NOT NULL,
    IssuedNumberId     BIGINT          NULL,
    NoteNumber         NVARCHAR(40)    NOT NULL,
    NoteDate           DATE            NOT NULL,
    ReasonCode         TINYINT         NOT NULL,          -- GSTR-1 codes: 1 return, 2 discount, 3 deficiency, 4 correction, 7 other
    ReasonText         NVARCHAR(300)   NULL,
    Status             TINYINT         NOT NULL CONSTRAINT DF_CreditNotes_Status DEFAULT (2),   -- 2 issued, 3 cancelled

    BuyerName          NVARCHAR(200)   NOT NULL,          -- as on the invoice
    BuyerGstin         VARCHAR(15)     NULL,
    BuyerAddress       NVARCHAR(500)   NULL,
    BuyerStateCode     VARCHAR(10)     NULL,
    PlaceOfSupply      VARCHAR(10)     NULL,
    IsInterState       BIT             NOT NULL,
    IsComposition      BIT             NOT NULL,
    IsReverseCharge    BIT             NOT NULL CONSTRAINT DF_CreditNotes_RCM DEFAULT (0),

    TaxableTotal       DECIMAL(18,2)   NOT NULL,
    CgstTotal          DECIMAL(18,2)   NOT NULL,
    SgstTotal          DECIMAL(18,2)   NOT NULL,
    IgstTotal          DECIMAL(18,2)   NOT NULL,
    ReimbursementTotal DECIMAL(18,2)   NOT NULL CONSTRAINT DF_CreditNotes_Reimb DEFAULT (0),
    RoundOff           DECIMAL(18,2)   NOT NULL CONSTRAINT DF_CreditNotes_RoundOff DEFAULT (0),
    GrandTotal         DECIMAL(18,2)   NOT NULL,

    Notes              NVARCHAR(1000)  NULL,
    SellerSnapshot     NVARCHAR(MAX)   NULL,
    CreatedAtUtc       DATETIME2(3)    NOT NULL CONSTRAINT DF_CreditNotes_Created DEFAULT (SYSUTCDATETIME()),
    CreatedBy          BIGINT          NULL,
    CancelledAtUtc     DATETIME2(3)    NULL,
    CancelledBy        BIGINT          NULL,
    CancelReason       NVARCHAR(200)   NULL,
    CONSTRAINT FK_CreditNotes_Tenant  FOREIGN KEY (TenantId) REFERENCES dbo.tbl_Tenants (TenantId),
    CONSTRAINT FK_CreditNotes_Profile FOREIGN KEY (BusinessProfileId) REFERENCES dbo.tbl_BusinessProfiles (BusinessProfileId),
    CONSTRAINT FK_CreditNotes_Invoice FOREIGN KEY (SalesInvoiceId) REFERENCES dbo.tbl_SalesInvoices (SalesInvoiceId),
    CONSTRAINT FK_CreditNotes_Party   FOREIGN KEY (PartyId) REFERENCES dbo.tbl_Parties (PartyId),
    CONSTRAINT CK_CreditNotes_Status  CHECK (Status IN (2, 3)),
    CONSTRAINT CK_CreditNotes_Reason  CHECK (ReasonCode IN (1, 2, 3, 4, 7)),
    CONSTRAINT CK_CreditNotes_Total   CHECK (GrandTotal > 0)
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CreditNotes_List')
    CREATE INDEX IX_CreditNotes_List ON dbo.tbl_CreditNotes (TenantId, NoteDate DESC) INCLUDE (NoteNumber, BuyerName, GrandTotal, Status, PartyId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CreditNotes_Invoice')
    CREATE INDEX IX_CreditNotes_Invoice ON dbo.tbl_CreditNotes (SalesInvoiceId) INCLUDE (Status, GrandTotal);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_CreditNotes_Number')
    CREATE UNIQUE INDEX UX_CreditNotes_Number ON dbo.tbl_CreditNotes (TenantId, NoteNumber);
GO

IF OBJECT_ID('dbo.tbl_CreditNoteLines') IS NULL
CREATE TABLE dbo.tbl_CreditNoteLines
(
    CreditNoteLineId   BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_CreditNoteLines PRIMARY KEY,
    CreditNoteId       BIGINT          NOT NULL,
    TenantId           BIGINT          NOT NULL,
    LineNumber         SMALLINT        NOT NULL,
    SalesInvoiceLineId BIGINT          NOT NULL,          -- the invoice line it takes back
    OfferingId         BIGINT          NULL,
    Description        NVARCHAR(300)   NOT NULL,
    HsnSacCode         VARCHAR(10)     NULL,
    Quantity           DECIMAL(18,4)   NOT NULL,          -- 0 when only the value is credited
    UnitCode           NVARCHAR(20)    NULL,
    UqcCode            VARCHAR(10)     NULL,
    TaxableValue       DECIMAL(18,2)   NOT NULL,
    TaxRatePercent     DECIMAL(7,4)    NOT NULL,
    CgstAmount         DECIMAL(18,2)   NOT NULL,
    SgstAmount         DECIMAL(18,2)   NOT NULL,
    IgstAmount         DECIMAL(18,2)   NOT NULL,
    LineTotal          DECIMAL(18,2)   NOT NULL,
    IsPureAgent        BIT             NOT NULL CONSTRAINT DF_CreditNoteLines_PA DEFAULT (0),
    CONSTRAINT FK_CreditNoteLines_Note FOREIGN KEY (CreditNoteId) REFERENCES dbo.tbl_CreditNotes (CreditNoteId) ON DELETE CASCADE,
    CONSTRAINT FK_CreditNoteLines_InvoiceLine FOREIGN KEY (SalesInvoiceLineId) REFERENCES dbo.tbl_SalesInvoiceLines (SalesInvoiceLineId),
    CONSTRAINT CK_CreditNoteLines_Amounts CHECK (Quantity >= 0 AND TaxableValue >= 0 AND (Quantity > 0 OR TaxableValue > 0))
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CreditNoteLines_InvoiceLine')
    CREATE INDEX IX_CreditNoteLines_InvoiceLine ON dbo.tbl_CreditNoteLines (SalesInvoiceLineId) INCLUDE (CreditNoteId, Quantity, TaxableValue, CgstAmount, SgstAmount, IgstAmount);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CreditNoteLines_Note')
    CREATE INDEX IX_CreditNoteLines_Note ON dbo.tbl_CreditNoteLines (CreditNoteId, LineNumber);
GO

/* Where a credit note's value went: the invoice it corrects, or the customer's other invoices. */
IF OBJECT_ID('dbo.tbl_CreditNoteAllocations') IS NULL
CREATE TABLE dbo.tbl_CreditNoteAllocations
(
    CreditNoteAllocationId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_CreditNoteAllocations PRIMARY KEY,
    CreditNoteId       BIGINT          NOT NULL,
    TenantId           BIGINT          NOT NULL,
    SalesInvoiceId     BIGINT          NOT NULL,
    Amount             DECIMAL(18,2)   NOT NULL,
    IsActive           BIT             NOT NULL CONSTRAINT DF_CreditNoteAllocations_Active DEFAULT (1),
    AllocatedAtUtc     DATETIME2(3)    NOT NULL CONSTRAINT DF_CreditNoteAllocations_At DEFAULT (SYSUTCDATETIME()),
    AllocatedBy        BIGINT          NULL,
    CONSTRAINT FK_CreditNoteAllocations_Note FOREIGN KEY (CreditNoteId) REFERENCES dbo.tbl_CreditNotes (CreditNoteId),
    CONSTRAINT FK_CreditNoteAllocations_Invoice FOREIGN KEY (SalesInvoiceId) REFERENCES dbo.tbl_SalesInvoices (SalesInvoiceId),
    CONSTRAINT CK_CreditNoteAllocations_Amount CHECK (Amount > 0)
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CreditNoteAllocations_Note')
    CREATE INDEX IX_CreditNoteAllocations_Note ON dbo.tbl_CreditNoteAllocations (CreditNoteId) INCLUDE (SalesInvoiceId, Amount, IsActive);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CreditNoteAllocations_Invoice')
    CREATE INDEX IX_CreditNoteAllocations_Invoice ON dbo.tbl_CreditNoteAllocations (SalesInvoiceId) INCLUDE (CreditNoteId, Amount, IsActive);
GO

/* Money paid back to the customer out of a credit note. */
IF OBJECT_ID('dbo.tbl_CreditNoteRefunds') IS NULL
CREATE TABLE dbo.tbl_CreditNoteRefunds
(
    CreditNoteRefundId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_CreditNoteRefunds PRIMARY KEY,
    CreditNoteId       BIGINT          NOT NULL,
    TenantId           BIGINT          NOT NULL,
    RefundDate         DATE            NOT NULL,
    Amount             DECIMAL(18,2)   NOT NULL,
    Mode               TINYINT         NOT NULL,          -- as tbl_Payments.Mode
    Reference          NVARCHAR(60)    NULL,
    BankAccountId      BIGINT          NULL,
    Notes              NVARCHAR(500)   NULL,
    IsActive           BIT             NOT NULL CONSTRAINT DF_CreditNoteRefunds_Active DEFAULT (1),
    CreatedAtUtc       DATETIME2(3)    NOT NULL CONSTRAINT DF_CreditNoteRefunds_Created DEFAULT (SYSUTCDATETIME()),
    CreatedBy          BIGINT          NULL,
    UndoneAtUtc        DATETIME2(3)    NULL,
    UndoneBy           BIGINT          NULL,
    UndoReason         NVARCHAR(200)   NULL,
    CONSTRAINT FK_CreditNoteRefunds_Note FOREIGN KEY (CreditNoteId) REFERENCES dbo.tbl_CreditNotes (CreditNoteId),
    CONSTRAINT CK_CreditNoteRefunds_Amount CHECK (Amount > 0),
    CONSTRAINT CK_CreditNoteRefunds_Mode CHECK (Mode BETWEEN 1 AND 6)
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CreditNoteRefunds_Note')
    CREATE INDEX IX_CreditNoteRefunds_Note ON dbo.tbl_CreditNoteRefunds (CreditNoteId) INCLUDE (Amount, IsActive);
GO

/* ============================================================================
   NEXT NUMBER (shared)

   Takes the next number from a profile's default series for a document type,
   creating the series on first use. Runs inside the caller's transaction; the
   caller records the number in tbl_IssuedNumbers once the document exists.
   ========================================================================= */
CREATE OR ALTER PROCEDURE dbo.usp_Number_Take
    @TenantId          BIGINT,
    @BusinessProfileId BIGINT,
    @DocumentType      TINYINT,
    @DefaultPrefix     NVARCHAR(10),
    @SeriesName        NVARCHAR(80),
    @DocumentDate      DATE,
    @ActionByUserId    BIGINT,
    @SeriesId          BIGINT OUTPUT,
    @FullNumber        NVARCHAR(40) OUTPUT,
    @Sequence          INT OUTPUT,
    @CounterYear       SMALLINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @SeriesId = NULL;
    SELECT @SeriesId = SeriesId FROM dbo.tbl_NumberSeries WITH (UPDLOCK)
     WHERE TenantId = @TenantId AND BusinessProfileId = @BusinessProfileId AND DocumentType = @DocumentType AND IsDefault = 1 AND IsActive = 1;

    IF @SeriesId IS NULL
    BEGIN
        DECLARE @prefix NVARCHAR(15) = @DefaultPrefix, @n INT = 2;
        WHILE EXISTS (SELECT 1 FROM dbo.tbl_NumberSeries WHERE TenantId = @TenantId AND DocumentType = @DocumentType AND IsActive = 1 AND Prefix = @prefix)
        BEGIN SET @prefix = CONCAT(@DefaultPrefix, @n); SET @n += 1; END
        INSERT INTO dbo.tbl_NumberSeries (TenantId, BusinessProfileId, DocumentType, SeriesName, Prefix, PadWidth, Separator,
                                          YearFormat, ResetYearly, StartFrom, IsDefault, IsActive, CreatedAtUtc, CreatedBy)
        VALUES(@TenantId, @BusinessProfileId, @DocumentType, @SeriesName, @prefix, 4, N'-', 2, 1, 1, 1, 1, SYSUTCDATETIME(), @ActionByUserId);
        SET @SeriesId = SCOPE_IDENTITY();
    END

    DECLARE @fy SMALLINT = dbo.fn_FinancialYear(@DocumentDate);
    DECLARE @sp NVARCHAR(15), @ss NVARCHAR(15), @sep NVARCHAR(3), @yf TINYINT, @pad TINYINT, @reset BIT, @start INT;
    SELECT @sp = Prefix, @ss = Suffix, @sep = Separator, @yf = YearFormat, @pad = PadWidth, @reset = ResetYearly, @start = StartFrom
      FROM dbo.tbl_NumberSeries WHERE SeriesId = @SeriesId;
    SET @CounterYear = CASE WHEN @reset = 0 THEN 0 ELSE @fy END;

    SET @Sequence = NULL;
    SELECT @Sequence = NextNumber FROM dbo.tbl_NumberCounters WITH (UPDLOCK, HOLDLOCK) WHERE SeriesId = @SeriesId AND FinancialYear = @CounterYear;
    IF @Sequence IS NULL
    BEGIN
        SET @Sequence = @start;
        INSERT INTO dbo.tbl_NumberCounters (SeriesId, FinancialYear, NextNumber, LastIssuedUtc) VALUES(@SeriesId, @CounterYear, @start + 1, SYSUTCDATETIME());
    END
    ELSE
        UPDATE dbo.tbl_NumberCounters SET NextNumber = NextNumber + 1, LastIssuedUtc = SYSUTCDATETIME() WHERE SeriesId = @SeriesId AND FinancialYear = @CounterYear;

    SET @FullNumber = dbo.fn_FormatDocNumber(@sp, @ss, @sep, @yf, @fy, @Sequence, @pad);
END
GO

/* ============================================================================
   ISSUE A CREDIT NOTE

   @Lines (JSON): SalesInvoiceLineId, Quantity, TaxableValue, TaxRatePercent,
   CgstAmount, SgstAmount, IgstAmount, LineTotal, IsPureAgent — computed by the
   application (BillingMadeEasy.Core CreditNoteMath). Descriptions, HSN and
   units are copied from the invoice line here, not taken from the request.
   ========================================================================= */
CREATE OR ALTER PROCEDURE dbo.usp_CreditNote_Issue
    @TenantId           BIGINT,
    @SalesInvoiceId     BIGINT,
    @NoteDate           DATE,
    @ReasonCode         TINYINT,
    @ReasonText         NVARCHAR(300) = NULL,
    @Notes              NVARCHAR(1000) = NULL,
    @TaxableTotal       DECIMAL(18,2),
    @CgstTotal          DECIMAL(18,2),
    @SgstTotal          DECIMAL(18,2),
    @IgstTotal          DECIMAL(18,2),
    @ReimbursementTotal DECIMAL(18,2),
    @RoundOff           DECIMAL(18,2),
    @GrandTotal         DECIMAL(18,2),
    @Lines              NVARCHAR(MAX),
    @SellerSnapshot     NVARCHAR(MAX),
    @Today              DATE,
    @ActionByUserId     BIGINT,
    @IpAddress          VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @ReasonText = NULLIF(LTRIM(RTRIM(ISNULL(@ReasonText, ''))), '');
    SET @Notes = NULLIF(LTRIM(RTRIM(ISNULL(@Notes, ''))), '');

    DECLARE @own BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    DECLARE @problem NVARCHAR(300), @field VARCHAR(40);
    DECLARE @status TINYINT, @profileId BIGINT, @partyId BIGINT, @invoiceNo NVARCHAR(40), @invoiceDate DATE, @invoiceTotal DECIMAL(18,2),
            @balance DECIMAL(18,2), @creditedBefore DECIMAL(18,2), @buyer NVARCHAR(200);
    DECLARE @noteId BIGINT, @number NVARCHAR(40), @seriesId BIGINT, @seq INT, @counterYear SMALLINT, @toInvoice DECIMAL(18,2) = 0;

    BEGIN TRY
        IF @own = 1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION sp_creditnote_issue;

        /* The invoice is locked until this commits: concurrent notes on it queue up behind this one. */
        SELECT @status = Status, @profileId = BusinessProfileId, @partyId = PartyId, @invoiceNo = InvoiceNumber,
               @invoiceDate = InvoiceDate, @invoiceTotal = GrandTotal, @balance = GrandTotal - AmountPaid, @buyer = BuyerName
          FROM dbo.tbl_SalesInvoices WITH (UPDLOCK, HOLDLOCK)
         WHERE SalesInvoiceId = @SalesInvoiceId AND TenantId = @TenantId;

        SELECT @creditedBefore = ISNULL(SUM(GrandTotal), 0) FROM dbo.tbl_CreditNotes WHERE SalesInvoiceId = @SalesInvoiceId AND Status = 2;

        DECLARE @l TABLE (SalesInvoiceLineId BIGINT PRIMARY KEY, Quantity DECIMAL(18,4), TaxableValue DECIMAL(18,2), TaxRatePercent DECIMAL(7,4),
                          CgstAmount DECIMAL(18,2), SgstAmount DECIMAL(18,2), IgstAmount DECIMAL(18,2), LineTotal DECIMAL(18,2), IsPureAgent BIT);
        INSERT INTO @l
        SELECT SalesInvoiceLineId, ISNULL(Quantity, 0), ISNULL(TaxableValue, 0), ISNULL(TaxRatePercent, 0), ISNULL(CgstAmount, 0), ISNULL(SgstAmount, 0),
               ISNULL(IgstAmount, 0), ISNULL(LineTotal, 0), ISNULL(IsPureAgent, 0)
          FROM OPENJSON(ISNULL(@Lines, N'[]')) WITH (SalesInvoiceLineId BIGINT, Quantity DECIMAL(18,4), TaxableValue DECIMAL(18,2), TaxRatePercent DECIMAL(7,4),
               CgstAmount DECIMAL(18,2), SgstAmount DECIMAL(18,2), IgstAmount DECIMAL(18,2), LineTotal DECIMAL(18,2), IsPureAgent BIT)
         WHERE SalesInvoiceLineId IS NOT NULL AND (ISNULL(Quantity, 0) > 0 OR ISNULL(TaxableValue, 0) > 0);

        SET @problem =
            CASE WHEN @status IS NULL THEN N'That invoice no longer exists'
                 WHEN @status = 1 THEN N'This invoice is still a draft. Edit it instead'
                 WHEN @status = 3 THEN N'This invoice is cancelled, so there is nothing to credit'
                 WHEN @ReasonCode NOT IN (1, 2, 3, 4, 7) THEN N'Choose why the credit note is being issued'
                 WHEN @ReasonCode = 7 AND @ReasonText IS NULL THEN N'Describe the reason'
                 WHEN @NoteDate > @Today THEN N'A credit note can''t be dated in the future'
                 WHEN @NoteDate < @invoiceDate THEN CONCAT(N'A credit note can''t be dated before its invoice (', FORMAT(@invoiceDate, 'd MMM yyyy', 'en-IN'), N')')
                 /* GST s.34(2): after 30 November following the invoice's financial year the tax can no longer be reduced. */
                 WHEN @NoteDate > DATEFROMPARTS(dbo.fn_FinancialYear(@invoiceDate) + 1, 11, 30)
                      THEN CONCAT(N'GST allows a credit note against ', @invoiceNo, N' only until ', FORMAT(DATEFROMPARTS(dbo.fn_FinancialYear(@invoiceDate) + 1, 11, 30), 'd MMM yyyy', 'en-IN'),
                                  N' (s.34). Settle the difference as a commercial discount instead')
                 WHEN NOT EXISTS (SELECT 1 FROM @l) THEN N'Enter what is being credited on at least one line'
                 WHEN EXISTS (SELECT 1 FROM @l l WHERE NOT EXISTS (SELECT 1 FROM dbo.tbl_SalesInvoiceLines o WHERE o.SalesInvoiceLineId = l.SalesInvoiceLineId AND o.SalesInvoiceId = @SalesInvoiceId))
                      THEN N'A line on this credit note is not on the invoice'
                 WHEN @ReasonCode = 1 AND NOT EXISTS (SELECT 1 FROM @l WHERE Quantity > 0) THEN N'Enter the quantity returned'
                 WHEN @GrandTotal IS NULL OR @GrandTotal <= 0 THEN N'The credit note total is zero. Enter quantities or values'
                 WHEN @creditedBefore + @GrandTotal > @invoiceTotal
                      THEN CONCAT(N'Only ', FORMAT(@invoiceTotal - @creditedBefore, 'N2', 'en-IN'), N' of ', @invoiceNo, N' is left to credit')
            END;
        SET @field = CASE WHEN @problem LIKE N'Choose why%' OR @problem LIKE N'Describe%' THEN 'ReasonCode'
                          WHEN @problem LIKE N'A credit note can%' OR @problem LIKE N'GST allows%' THEN 'NoteDate' END;

        /* Line by line: never more quantity or value than the invoice line had, counting earlier notes. */
        IF @problem IS NULL
            SELECT TOP (1) @problem =
                   CONCAT(N'Line ', o.LineNumber, N' (', o.Description, N') ',
                          CASE WHEN l.Quantity > o.Quantity - ISNULL(p.Qty, 0)
                               THEN CONCAT(N'has only ', FORMAT(o.Quantity - ISNULL(p.Qty, 0), '0.####'), N' left to credit')
                               ELSE CONCAT(N'has only ', FORMAT(o.TaxableValue - ISNULL(p.Taxable, 0), 'N2', 'en-IN'), N' of value left to credit') END)
              FROM @l l
              JOIN dbo.tbl_SalesInvoiceLines o ON o.SalesInvoiceLineId = l.SalesInvoiceLineId
              LEFT JOIN (SELECT cl.SalesInvoiceLineId, Qty = SUM(cl.Quantity), Taxable = SUM(cl.TaxableValue)
                           FROM dbo.tbl_CreditNoteLines cl JOIN dbo.tbl_CreditNotes c ON c.CreditNoteId = cl.CreditNoteId
                          WHERE c.SalesInvoiceId = @SalesInvoiceId AND c.Status = 2
                          GROUP BY cl.SalesInvoiceLineId) p ON p.SalesInvoiceLineId = l.SalesInvoiceLineId
             WHERE l.Quantity > o.Quantity - ISNULL(p.Qty, 0) OR l.TaxableValue > o.TaxableValue - ISNULL(p.Taxable, 0)
             ORDER BY o.LineNumber;

        IF @problem IS NOT NULL
        BEGIN
            IF @own = 1 ROLLBACK TRANSACTION; ELSE ROLLBACK TRANSACTION sp_creditnote_issue;
            SELECT ResultCode = 5, ResultMessage = @problem, FieldName = @field, CreditNoteId = CONVERT(BIGINT, NULL), NoteNumber = CONVERT(NVARCHAR(40), NULL);
            RETURN;
        END

        EXEC dbo.usp_Number_Take @TenantId = @TenantId, @BusinessProfileId = @profileId, @DocumentType = 3, @DefaultPrefix = N'CN',
                                 @SeriesName = N'Credit notes', @DocumentDate = @NoteDate, @ActionByUserId = @ActionByUserId,
                                 @SeriesId = @seriesId OUTPUT, @FullNumber = @number OUTPUT, @Sequence = @seq OUTPUT, @CounterYear = @counterYear OUTPUT;

        INSERT INTO dbo.tbl_CreditNotes
              (TenantId, BusinessProfileId, SalesInvoiceId, PartyId, SeriesId, NoteNumber, NoteDate, ReasonCode, ReasonText,
               BuyerName, BuyerGstin, BuyerAddress, BuyerStateCode, PlaceOfSupply, IsInterState, IsComposition, IsReverseCharge,
               TaxableTotal, CgstTotal, SgstTotal, IgstTotal, ReimbursementTotal, RoundOff, GrandTotal, Notes, SellerSnapshot, CreatedBy)
        SELECT @TenantId, @profileId, @SalesInvoiceId, PartyId, @seriesId, @number, @NoteDate, @ReasonCode, @ReasonText,
               BuyerName, BuyerGstin, BuyerAddress, BuyerStateCode, PlaceOfSupply, IsInterState, IsComposition, IsReverseCharge,
               @TaxableTotal, @CgstTotal, @SgstTotal, @IgstTotal, @ReimbursementTotal, @RoundOff, @GrandTotal, @Notes, @SellerSnapshot, @ActionByUserId
          FROM dbo.tbl_SalesInvoices WHERE SalesInvoiceId = @SalesInvoiceId;
        SET @noteId = SCOPE_IDENTITY();

        INSERT INTO dbo.tbl_CreditNoteLines
              (CreditNoteId, TenantId, LineNumber, SalesInvoiceLineId, OfferingId, Description, HsnSacCode, Quantity, UnitCode, UqcCode,
               TaxableValue, TaxRatePercent, CgstAmount, SgstAmount, IgstAmount, LineTotal, IsPureAgent)
        SELECT @noteId, @TenantId, ROW_NUMBER() OVER (ORDER BY o.LineNumber), o.SalesInvoiceLineId, o.OfferingId, o.Description, o.HsnSacCode,
               l.Quantity, o.UnitCode, o.UqcCode, l.TaxableValue, o.TaxRatePercent, l.CgstAmount, l.SgstAmount, l.IgstAmount, l.LineTotal, o.IsPureAgent
          FROM @l l JOIN dbo.tbl_SalesInvoiceLines o ON o.SalesInvoiceLineId = l.SalesInvoiceLineId;

        INSERT INTO dbo.tbl_IssuedNumbers (TenantId, SeriesId, FinancialYear, SequenceNumber, FullNumber, DocumentType, DocumentId, DocumentDate, IssuedBy)
        VALUES(@TenantId, @seriesId, @counterYear, @seq, @number, 3, @noteId, @NoteDate, @ActionByUserId);
        UPDATE dbo.tbl_CreditNotes SET IssuedNumberId = SCOPE_IDENTITY() WHERE CreditNoteId = @noteId;

        /* First it reduces what is still owed on the invoice it corrects. */
        SET @toInvoice = CASE WHEN @balance <= 0 THEN 0 WHEN @balance < @GrandTotal THEN @balance ELSE @GrandTotal END;
        IF @toInvoice > 0
        BEGIN
            INSERT INTO dbo.tbl_CreditNoteAllocations (CreditNoteId, TenantId, SalesInvoiceId, Amount, AllocatedBy)
            VALUES(@noteId, @TenantId, @SalesInvoiceId, @toInvoice, @ActionByUserId);
            UPDATE dbo.tbl_SalesInvoices
               SET AmountPaid = AmountPaid + @toInvoice, CreditedAmount = CreditedAmount + @toInvoice,
                   UpdatedAtUtc = SYSUTCDATETIME(), UpdatedBy = @ActionByUserId
             WHERE SalesInvoiceId = @SalesInvoiceId;
        END

        INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, IpAddress)
        VALUES(@TenantId, @ActionByUserId, 'CreditNote.Issued', 'CreditNote', @noteId, @number,
               CONCAT(N'Credit note ', @number, N' against ', @invoiceNo, N' to ', @buyer, N' for ₹', FORMAT(@GrandTotal, 'N2', 'en-IN')), @IpAddress);

        IF @own = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @own = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok', FieldName = CONVERT(VARCHAR(40), NULL), CreditNoteId = @noteId, NoteNumber = @number,
           AppliedToInvoice = @toInvoice, CreditLeft = @GrandTotal - @toInvoice;
END
GO

/* What is left of a credit note to apply or refund. */
CREATE OR ALTER FUNCTION dbo.fn_CreditNoteLeft (@CreditNoteId BIGINT)
RETURNS DECIMAL(18,2)
AS
BEGIN
    RETURN (SELECT CASE WHEN c.Status = 2 THEN c.GrandTotal
                        - ISNULL((SELECT SUM(Amount) FROM dbo.tbl_CreditNoteAllocations WHERE CreditNoteId = c.CreditNoteId AND IsActive = 1), 0)
                        - ISNULL((SELECT SUM(Amount) FROM dbo.tbl_CreditNoteRefunds WHERE CreditNoteId = c.CreditNoteId AND IsActive = 1), 0)
                        ELSE 0 END
              FROM dbo.tbl_CreditNotes c WHERE c.CreditNoteId = @CreditNoteId);
END
GO

/* Apply what is left of a credit note to the customer's other invoices. @Allocations: JSON SalesInvoiceId, Amount. */
CREATE OR ALTER PROCEDURE dbo.usp_CreditNote_Apply
    @TenantId       BIGINT,
    @CreditNoteId   BIGINT,
    @Allocations    NVARCHAR(MAX),
    @ActionByUserId BIGINT,
    @IpAddress      VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @own BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END, @problem NVARCHAR(300);
    DECLARE @status TINYINT, @partyId BIGINT, @profileId BIGINT, @number NVARCHAR(40), @left DECIMAL(18,2);

    BEGIN TRY
        IF @own = 1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION sp_creditnote_apply;

        SELECT @status = Status, @partyId = PartyId, @profileId = BusinessProfileId, @number = NoteNumber
          FROM dbo.tbl_CreditNotes WITH (UPDLOCK, HOLDLOCK) WHERE CreditNoteId = @CreditNoteId AND TenantId = @TenantId;
        SET @left = dbo.fn_CreditNoteLeft(@CreditNoteId);

        DECLARE @a TABLE (SalesInvoiceId BIGINT PRIMARY KEY, Amount DECIMAL(18,2));
        INSERT INTO @a
        SELECT SalesInvoiceId, SUM(ISNULL(Amount, 0))
          FROM OPENJSON(ISNULL(@Allocations, N'[]')) WITH (SalesInvoiceId BIGINT, Amount DECIMAL(18,2))
         WHERE SalesInvoiceId IS NOT NULL
         GROUP BY SalesInvoiceId HAVING SUM(ISNULL(Amount, 0)) <> 0;

        DECLARE @inv TABLE (SalesInvoiceId BIGINT PRIMARY KEY, InvoiceNumber NVARCHAR(40), Balance DECIMAL(18,2), Status TINYINT, PartyId BIGINT NULL, BusinessProfileId BIGINT);
        INSERT INTO @inv
        SELECT i.SalesInvoiceId, i.InvoiceNumber, i.GrandTotal - i.AmountPaid, i.Status, i.PartyId, i.BusinessProfileId
          FROM dbo.tbl_SalesInvoices i WITH (UPDLOCK, HOLDLOCK) JOIN @a a ON a.SalesInvoiceId = i.SalesInvoiceId
         WHERE i.TenantId = @TenantId;

        SET @problem =
            CASE WHEN @status IS NULL THEN N'That credit note no longer exists'
                 WHEN @status = 3 THEN N'This credit note is cancelled'
                 WHEN @partyId IS NULL THEN N'This customer has no account to carry a credit. Refund it instead'
                 WHEN NOT EXISTS (SELECT 1 FROM @a) THEN N'Enter an amount against at least one invoice'
                 WHEN EXISTS (SELECT 1 FROM @a WHERE Amount < 0) THEN N'Amounts can''t be negative'
                 WHEN (SELECT SUM(Amount) FROM @a) > @left THEN CONCAT(N'Only ', FORMAT(@left, 'N2', 'en-IN'), N' of ', @number, N' is left to apply')
            END;
        IF @problem IS NULL
            SELECT TOP (1) @problem =
                   CASE WHEN v.SalesInvoiceId IS NULL THEN N'An invoice chosen no longer exists'
                        WHEN v.Status <> 2 THEN CONCAT(ISNULL(v.InvoiceNumber, N'A draft'), N' is not an issued invoice')
                        WHEN ISNULL(v.PartyId, -1) <> @partyId THEN CONCAT(v.InvoiceNumber, N' belongs to another customer')
                        WHEN v.BusinessProfileId <> @profileId THEN CONCAT(v.InvoiceNumber, N' was issued by another of your businesses')
                        ELSE CONCAT(v.InvoiceNumber, N' has only ', FORMAT(v.Balance, 'N2', 'en-IN'), N' left to pay') END
              FROM @a a LEFT JOIN @inv v ON v.SalesInvoiceId = a.SalesInvoiceId
             WHERE v.SalesInvoiceId IS NULL OR v.Status <> 2 OR ISNULL(v.PartyId, -1) <> @partyId OR v.BusinessProfileId <> @profileId OR a.Amount > v.Balance;

        IF @problem IS NOT NULL
        BEGIN
            IF @own = 1 ROLLBACK TRANSACTION; ELSE ROLLBACK TRANSACTION sp_creditnote_apply;
            SELECT ResultCode = 5, ResultMessage = @problem;
            RETURN;
        END

        INSERT INTO dbo.tbl_CreditNoteAllocations (CreditNoteId, TenantId, SalesInvoiceId, Amount, AllocatedBy)
        SELECT @CreditNoteId, @TenantId, SalesInvoiceId, Amount, @ActionByUserId FROM @a WHERE Amount > 0;

        UPDATE i SET AmountPaid = i.AmountPaid + a.Amount, CreditedAmount = i.CreditedAmount + a.Amount,
                     UpdatedAtUtc = SYSUTCDATETIME(), UpdatedBy = @ActionByUserId
          FROM dbo.tbl_SalesInvoices i JOIN @a a ON a.SalesInvoiceId = i.SalesInvoiceId;

        INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, IpAddress)
        VALUES(@TenantId, @ActionByUserId, 'CreditNote.Applied', 'CreditNote', @CreditNoteId, @number,
               CONCAT(N'Applied ₹', FORMAT((SELECT SUM(Amount) FROM @a), 'N2', 'en-IN'), N' of ', @number, N' to ',
                      STUFF((SELECT N', ' + InvoiceNumber FROM @inv FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, N'')), @IpAddress);

        IF @own = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @own = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok';
END
GO

/* Pay back what is left of a credit note. */
CREATE OR ALTER PROCEDURE dbo.usp_CreditNote_Refund
    @TenantId       BIGINT,
    @CreditNoteId   BIGINT,
    @RefundDate     DATE,
    @Amount         DECIMAL(18,2),
    @Mode           TINYINT,
    @Reference      NVARCHAR(60) = NULL,
    @BankAccountId  BIGINT = NULL,
    @Notes          NVARCHAR(500) = NULL,
    @Today          DATE,
    @ActionByUserId BIGINT,
    @IpAddress      VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Reference = NULLIF(LTRIM(RTRIM(ISNULL(@Reference, ''))), '');
    DECLARE @own BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END, @problem NVARCHAR(300);
    DECLARE @status TINYINT, @number NVARCHAR(40), @noteDate DATE, @buyer NVARCHAR(200), @left DECIMAL(18,2);

    BEGIN TRY
        IF @own = 1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION sp_creditnote_refund;

        SELECT @status = Status, @number = NoteNumber, @noteDate = NoteDate, @buyer = BuyerName
          FROM dbo.tbl_CreditNotes WITH (UPDLOCK, HOLDLOCK) WHERE CreditNoteId = @CreditNoteId AND TenantId = @TenantId;
        SET @left = dbo.fn_CreditNoteLeft(@CreditNoteId);

        SET @problem =
            CASE WHEN @status IS NULL THEN N'That credit note no longer exists'
                 WHEN @status = 3 THEN N'This credit note is cancelled'
                 WHEN @Amount IS NULL OR @Amount <= 0 THEN N'Enter the amount refunded'
                 WHEN @Amount > @left THEN CONCAT(N'Only ', FORMAT(@left, 'N2', 'en-IN'), N' of ', @number, N' is left to refund')
                 WHEN @RefundDate > @Today THEN N'A refund can''t be dated in the future'
                 WHEN @RefundDate < @noteDate THEN N'A refund can''t be dated before its credit note'
                 WHEN @Mode NOT BETWEEN 1 AND 6 THEN N'Choose how it was paid back'
                 WHEN @BankAccountId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.tbl_BusinessBankAccounts WHERE BankAccountId = @BankAccountId AND TenantId = @TenantId)
                      THEN N'Choose one of your bank accounts'
            END;
        IF @problem IS NOT NULL
        BEGIN
            IF @own = 1 ROLLBACK TRANSACTION; ELSE ROLLBACK TRANSACTION sp_creditnote_refund;
            SELECT ResultCode = 5, ResultMessage = @problem;
            RETURN;
        END

        INSERT INTO dbo.tbl_CreditNoteRefunds (CreditNoteId, TenantId, RefundDate, Amount, Mode, Reference, BankAccountId, Notes, CreatedBy)
        VALUES(@CreditNoteId, @TenantId, @RefundDate, @Amount, @Mode, @Reference, @BankAccountId, NULLIF(LTRIM(RTRIM(ISNULL(@Notes, ''))), ''), @ActionByUserId);

        INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, IpAddress)
        VALUES(@TenantId, @ActionByUserId, 'CreditNote.Refunded', 'CreditNote', @CreditNoteId, @number,
               CONCAT(N'Refunded ₹', FORMAT(@Amount, 'N2', 'en-IN'), N' to ', @buyer, N' against ', @number), @IpAddress);

        IF @own = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @own = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok';
END
GO

/* A refund recorded by mistake, or one that failed (bounced, returned by the bank). */
CREATE OR ALTER PROCEDURE dbo.usp_CreditNote_RefundUndo
    @TenantId           BIGINT,
    @CreditNoteRefundId BIGINT,
    @Reason             NVARCHAR(200),
    @ActionByUserId     BIGINT,
    @IpAddress          VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @Reason = NULLIF(LTRIM(RTRIM(ISNULL(@Reason, ''))), '');

    DECLARE @noteId BIGINT, @active BIT, @amount DECIMAL(18,2), @number NVARCHAR(40);
    SELECT @noteId = r.CreditNoteId, @active = r.IsActive, @amount = r.Amount, @number = c.NoteNumber
      FROM dbo.tbl_CreditNoteRefunds r JOIN dbo.tbl_CreditNotes c ON c.CreditNoteId = r.CreditNoteId
     WHERE r.CreditNoteRefundId = @CreditNoteRefundId AND r.TenantId = @TenantId;

    IF @noteId IS NULL BEGIN SELECT ResultCode = 1, ResultMessage = N'That refund no longer exists', CreditNoteId = CONVERT(BIGINT, NULL); RETURN; END
    IF @active = 0 BEGIN SELECT ResultCode = 5, ResultMessage = N'This refund is already undone', CreditNoteId = @noteId; RETURN; END
    IF @Reason IS NULL OR LEN(@Reason) < 3 BEGIN SELECT ResultCode = 5, ResultMessage = N'Say why the refund is being undone. The reason stays on record', CreditNoteId = @noteId; RETURN; END

    UPDATE dbo.tbl_CreditNoteRefunds
       SET IsActive = 0, UndoneAtUtc = SYSUTCDATETIME(), UndoneBy = @ActionByUserId, UndoReason = @Reason
     WHERE CreditNoteRefundId = @CreditNoteRefundId AND IsActive = 1;

    INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, IpAddress)
    VALUES(@TenantId, @ActionByUserId, 'CreditNote.RefundUndone', 'CreditNote', @noteId, @number,
           CONCAT(N'Undid refund of ₹', FORMAT(@amount, 'N2', 'en-IN'), N' on ', @number, N': ', @Reason), @IpAddress);

    SELECT ResultCode = 0, ResultMessage = N'Ok', CreditNoteId = @noteId;
END
GO

/* Cancel a credit note issued by mistake. The invoices it settled owe again; the number stays in the register. */
CREATE OR ALTER PROCEDURE dbo.usp_CreditNote_Cancel
    @TenantId       BIGINT,
    @CreditNoteId   BIGINT,
    @Reason         NVARCHAR(200),
    @ActionByUserId BIGINT,
    @IpAddress      VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Reason = NULLIF(LTRIM(RTRIM(ISNULL(@Reason, ''))), '');
    DECLARE @own BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END, @problem NVARCHAR(300);
    DECLARE @status TINYINT, @number NVARCHAR(40), @total DECIMAL(18,2);

    BEGIN TRY
        IF @own = 1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION sp_creditnote_cancel;

        SELECT @status = Status, @number = NoteNumber, @total = GrandTotal
          FROM dbo.tbl_CreditNotes WITH (UPDLOCK, HOLDLOCK) WHERE CreditNoteId = @CreditNoteId AND TenantId = @TenantId;

        SET @problem =
            CASE WHEN @status IS NULL THEN N'That credit note no longer exists'
                 WHEN @status = 3 THEN N'This credit note is already cancelled'
                 WHEN EXISTS (SELECT 1 FROM dbo.tbl_CreditNoteRefunds WHERE CreditNoteId = @CreditNoteId AND IsActive = 1)
                      THEN N'Money has been refunded against this credit note. Undo the refund first'
                 WHEN @Reason IS NULL OR LEN(@Reason) < 3 THEN N'Say why it is being cancelled. The reason stays on record'
            END;
        IF @problem IS NOT NULL
        BEGIN
            IF @own = 1 ROLLBACK TRANSACTION; ELSE ROLLBACK TRANSACTION sp_creditnote_cancel;
            SELECT ResultCode = 5, ResultMessage = @problem;
            RETURN;
        END

        UPDATE i
           SET AmountPaid = i.AmountPaid - a.Amount, CreditedAmount = i.CreditedAmount - a.Amount,
               UpdatedAtUtc = SYSUTCDATETIME(), UpdatedBy = @ActionByUserId
          FROM dbo.tbl_SalesInvoices i WITH (UPDLOCK)
          JOIN (SELECT SalesInvoiceId, Amount = SUM(Amount) FROM dbo.tbl_CreditNoteAllocations
                 WHERE CreditNoteId = @CreditNoteId AND IsActive = 1 GROUP BY SalesInvoiceId) a ON a.SalesInvoiceId = i.SalesInvoiceId;

        UPDATE dbo.tbl_CreditNoteAllocations SET IsActive = 0 WHERE CreditNoteId = @CreditNoteId AND IsActive = 1;

        UPDATE dbo.tbl_CreditNotes
           SET Status = 3, CancelledAtUtc = SYSUTCDATETIME(), CancelledBy = @ActionByUserId, CancelReason = @Reason
         WHERE CreditNoteId = @CreditNoteId;

        UPDATE dbo.tbl_IssuedNumbers SET IsCancelled = 1, CancelledAtUtc = SYSUTCDATETIME(), CancelReason = @Reason
         WHERE TenantId = @TenantId AND DocumentType = 3 AND DocumentId = @CreditNoteId;

        INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, IpAddress)
        VALUES(@TenantId, @ActionByUserId, 'CreditNote.Cancelled', 'CreditNote', @CreditNoteId, @number,
               CONCAT(N'Cancelled ', @number, N' (₹', FORMAT(@total, 'N2', 'en-IN'), N'): ', @Reason), @IpAddress);

        IF @own = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @own = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok';
END
GO

/* An invoice's lines with what earlier credit notes took back, for a new note. */
CREATE OR ALTER PROCEDURE dbo.usp_CreditNote_Creditable
    @TenantId       BIGINT,
    @SalesInvoiceId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT o.SalesInvoiceLineId, o.LineNumber, o.Description, o.HsnSacCode, o.Quantity, o.UnitCode, o.Rate, o.TaxableValue,
           o.TaxRatePercent, o.CgstAmount, o.SgstAmount, o.IgstAmount, o.LineTotal, o.IsPureAgent,
           CreditedQuantity = ISNULL(p.Qty, 0), CreditedTaxable = ISNULL(p.Taxable, 0),
           CreditedCgst = ISNULL(p.Cgst, 0), CreditedSgst = ISNULL(p.Sgst, 0), CreditedIgst = ISNULL(p.Igst, 0)
      FROM dbo.tbl_SalesInvoiceLines o
      JOIN dbo.tbl_SalesInvoices i ON i.SalesInvoiceId = o.SalesInvoiceId
      LEFT JOIN (SELECT cl.SalesInvoiceLineId, Qty = SUM(cl.Quantity), Taxable = SUM(cl.TaxableValue),
                        Cgst = SUM(cl.CgstAmount), Sgst = SUM(cl.SgstAmount), Igst = SUM(cl.IgstAmount)
                   FROM dbo.tbl_CreditNoteLines cl JOIN dbo.tbl_CreditNotes c ON c.CreditNoteId = cl.CreditNoteId
                  WHERE c.SalesInvoiceId = @SalesInvoiceId AND c.Status = 2
                  GROUP BY cl.SalesInvoiceLineId) p ON p.SalesInvoiceLineId = o.SalesInvoiceLineId
     WHERE o.SalesInvoiceId = @SalesInvoiceId AND i.TenantId = @TenantId
     ORDER BY o.LineNumber;

    SELECT c.CreditNoteId, c.NoteNumber, c.NoteDate, c.ReasonCode, c.ReasonText, c.GrandTotal, c.Status, c.CancelReason,
           CreditLeft = dbo.fn_CreditNoteLeft(c.CreditNoteId)
      FROM dbo.tbl_CreditNotes c
     WHERE c.SalesInvoiceId = @SalesInvoiceId AND c.TenantId = @TenantId
     ORDER BY c.NoteDate, c.CreditNoteId;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_CreditNote_Get
    @TenantId     BIGINT,
    @CreditNoteId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT c.*, InvoiceNumber = i.InvoiceNumber, InvoiceDate = i.InvoiceDate, InvoiceTotal = i.GrandTotal, InvoiceDocumentType = i.DocumentType,
           PlaceOfSupplyName = s.StateName,
           Applied = ISNULL((SELECT SUM(Amount) FROM dbo.tbl_CreditNoteAllocations WHERE CreditNoteId = c.CreditNoteId AND IsActive = 1), 0),
           Refunded = ISNULL((SELECT SUM(Amount) FROM dbo.tbl_CreditNoteRefunds WHERE CreditNoteId = c.CreditNoteId AND IsActive = 1), 0),
           CreditLeft = dbo.fn_CreditNoteLeft(c.CreditNoteId),
           CreatedByName = cu.FullName, CancelledByName = xu.FullName
      FROM dbo.tbl_CreditNotes c
      JOIN dbo.tbl_SalesInvoices i ON i.SalesInvoiceId = c.SalesInvoiceId
      LEFT JOIN dbo.tbl_StateCodes s ON s.CountryCode = 'IN' AND s.StateCode = c.PlaceOfSupply
      LEFT JOIN dbo.tbl_Users cu ON cu.UserId = c.CreatedBy
      LEFT JOIN dbo.tbl_Users xu ON xu.UserId = c.CancelledBy
     WHERE c.CreditNoteId = @CreditNoteId AND c.TenantId = @TenantId;

    SELECT l.*
      FROM dbo.tbl_CreditNoteLines l
     WHERE l.CreditNoteId = @CreditNoteId AND l.TenantId = @TenantId
     ORDER BY l.LineNumber;

    SELECT a.CreditNoteAllocationId, a.SalesInvoiceId, i.InvoiceNumber, i.InvoiceDate, a.Amount, a.IsActive, a.AllocatedAtUtc
      FROM dbo.tbl_CreditNoteAllocations a
      JOIN dbo.tbl_SalesInvoices i ON i.SalesInvoiceId = a.SalesInvoiceId
     WHERE a.CreditNoteId = @CreditNoteId AND a.TenantId = @TenantId
     ORDER BY a.AllocatedAtUtc, a.CreditNoteAllocationId;

    SELECT r.CreditNoteRefundId, r.RefundDate, r.Amount, r.Mode, r.Reference, r.Notes, r.IsActive, r.UndoReason,
           b.BankName, BankAccountNumber = b.AccountNumber
      FROM dbo.tbl_CreditNoteRefunds r
      LEFT JOIN dbo.tbl_BusinessBankAccounts b ON b.BankAccountId = r.BankAccountId
     WHERE r.CreditNoteId = @CreditNoteId AND r.TenantId = @TenantId
     ORDER BY r.RefundDate, r.CreditNoteRefundId;
END
GO

/* @View: 'all', 'open' (credit left to apply or refund), 'cancelled'. */
CREATE OR ALTER PROCEDURE dbo.usp_CreditNote_List
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

    ;WITH used AS
    (
        SELECT c.CreditNoteId,
               Applied = ISNULL((SELECT SUM(Amount) FROM dbo.tbl_CreditNoteAllocations a WHERE a.CreditNoteId = c.CreditNoteId AND a.IsActive = 1), 0),
               Refunded = ISNULL((SELECT SUM(Amount) FROM dbo.tbl_CreditNoteRefunds r WHERE r.CreditNoteId = c.CreditNoteId AND r.IsActive = 1), 0)
          FROM dbo.tbl_CreditNotes c WHERE c.TenantId = @TenantId
    ),
    v AS
    (
        SELECT c.CreditNoteId, c.NoteNumber, c.NoteDate, c.PartyId, c.BuyerName, c.BuyerGstin, c.ReasonCode, c.Status,
               c.TaxableTotal, Tax = c.CgstTotal + c.SgstTotal + c.IgstTotal, c.GrandTotal,
               CreditLeft = CASE WHEN c.Status = 2 THEN c.GrandTotal - u.Applied - u.Refunded ELSE 0 END,
               c.SalesInvoiceId, InvoiceNumber = i.InvoiceNumber
          FROM dbo.tbl_CreditNotes c
          JOIN used u ON u.CreditNoteId = c.CreditNoteId
          JOIN dbo.tbl_SalesInvoices i ON i.SalesInvoiceId = c.SalesInvoiceId
         WHERE c.TenantId = @TenantId
           AND (@PartyId IS NULL OR c.PartyId = @PartyId)
           AND (@Search IS NULL OR c.NoteNumber LIKE @like OR c.BuyerName LIKE @like OR c.BuyerGstin LIKE @like OR i.InvoiceNumber LIKE @like)
    )
    SELECT *, Total = COUNT(*) OVER ()
      FROM v
     WHERE @View = 'all' OR (@View = 'open' AND CreditLeft > 0) OR (@View = 'cancelled' AND Status = 3)
     ORDER BY NoteDate DESC, CreditNoteId DESC
    OFFSET (@Page - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    DECLARE @monthStart DATE = DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1);
    SELECT CreditedThisMonth = ISNULL(SUM(CASE WHEN c.Status = 2 AND c.NoteDate >= @monthStart THEN c.GrandTotal END), 0),
           TaxThisMonth = ISNULL(SUM(CASE WHEN c.Status = 2 AND c.NoteDate >= @monthStart THEN c.CgstTotal + c.SgstTotal + c.IgstTotal END), 0),
           NotesThisMonth = ISNULL(SUM(CASE WHEN c.Status = 2 AND c.NoteDate >= @monthStart THEN 1 END), 0),
           OpenCredit = ISNULL(SUM(CASE WHEN c.Status = 2 THEN dbo.fn_CreditNoteLeft(c.CreditNoteId) END), 0)
      FROM dbo.tbl_CreditNotes c
     WHERE c.TenantId = @TenantId AND (@PartyId IS NULL OR c.PartyId = @PartyId);
END
GO

/* A customer's credit notes with credit left, for the payment screen. */
CREATE OR ALTER PROCEDURE dbo.usp_CreditNote_OpenForParty
    @TenantId BIGINT,
    @PartyId  BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CreditNoteId, NoteNumber, NoteDate, GrandTotal, CreditLeft
      FROM (SELECT c.CreditNoteId, c.NoteNumber, c.NoteDate, c.GrandTotal, CreditLeft = dbo.fn_CreditNoteLeft(c.CreditNoteId)
              FROM dbo.tbl_CreditNotes c
             WHERE c.TenantId = @TenantId AND c.PartyId = @PartyId AND c.Status = 2) x
     WHERE CreditLeft > 0
     ORDER BY NoteDate, CreditNoteId;
END
GO

/* ============================================================================
   Invoice cancel: an invoice with credit notes can't be cancelled underneath them.
   (Replaces the version in 37.)
   ========================================================================= */
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

        DECLARE @problem NVARCHAR(300) =
            CASE WHEN EXISTS (SELECT 1 FROM dbo.tbl_CreditNotes WHERE SalesInvoiceId = @SalesInvoiceId AND Status = 2)
                      THEN N'Credit notes are issued against this invoice. Cancel them first, or leave the invoice as it is'
                 WHEN EXISTS (SELECT 1 FROM dbo.tbl_CreditNoteAllocations WHERE SalesInvoiceId = @SalesInvoiceId AND IsActive = 1)
                      THEN N'A credit note has been applied to this invoice. Cancel that credit note first'
                 WHEN @paid > 0 THEN N'Payments are recorded against this invoice. Reverse them first, or raise a credit note instead'
                 WHEN LEN(LTRIM(RTRIM(ISNULL(@Reason, '')))) < 3 THEN N'Say why it is being cancelled. The reason stays on record'
            END;
        IF @problem IS NOT NULL
        BEGIN
            IF @own = 1 ROLLBACK TRANSACTION; ELSE ROLLBACK TRANSACTION sp_invoice_cancel;
            SELECT ResultCode = 5, ResultMessage = @problem, Discarded = CONVERT(BIT, 0);
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
