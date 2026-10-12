/* 38 · Payments received
   ------------------------------------------------------------------
   A payment is money in: cash, UPI, a bank transfer, a cheque. One payment
   can settle several invoices, and part of an invoice can be settled by TDS
   the customer deducted (and deposits with the government on your behalf),
   so each allocation records the money and the TDS separately.

   Whatever is not allocated stays on the payment as an advance, to be applied
   to later invoices. Every payment gets a receipt number from the profile's
   receipt series; reversing a payment (a bounced cheque, a mistake) needs a
   reason, restores the invoices' balances, and keeps the number.

   tbl_SalesInvoices.AmountPaid remains "settled so far" (money + TDS);
   TdsDeducted says how much of it was TDS.

   Safe to run more than once. */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF COL_LENGTH('dbo.tbl_SalesInvoices', 'TdsDeducted') IS NULL
    ALTER TABLE dbo.tbl_SalesInvoices ADD TdsDeducted DECIMAL(18,2) NOT NULL CONSTRAINT DF_SalesInvoices_Tds DEFAULT (0);
GO

IF OBJECT_ID('dbo.tbl_Payments') IS NULL
CREATE TABLE dbo.tbl_Payments
(
    PaymentId          BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Payments PRIMARY KEY,
    TenantId           BIGINT          NOT NULL,
    BusinessProfileId  BIGINT          NOT NULL,
    PartyId            BIGINT          NULL,
    PayerName          NVARCHAR(200)   NOT NULL,
    SeriesId           BIGINT          NULL,
    IssuedNumberId     BIGINT          NULL,
    ReceiptNumber      NVARCHAR(40)    NOT NULL,
    PaymentDate        DATE            NOT NULL,
    Amount             DECIMAL(18,2)   NOT NULL,          -- money received
    TdsAmount          DECIMAL(18,2)   NOT NULL CONSTRAINT DF_Payments_Tds DEFAULT (0),
    Mode               TINYINT         NOT NULL,          -- 1 cash, 2 UPI, 3 bank transfer, 4 cheque, 5 card, 6 other
    Reference          NVARCHAR(60)    NULL,              -- UTR, cheque number, card approval code
    InstrumentDate     DATE            NULL,              -- the cheque's date
    BankAccountId      BIGINT          NULL,              -- which of your accounts it went into
    Notes              NVARCHAR(500)   NULL,
    Status             TINYINT         NOT NULL CONSTRAINT DF_Payments_Status DEFAULT (1),   -- 1 recorded, 2 reversed
    ReversedAtUtc      DATETIME2(3)    NULL,
    ReversedBy         BIGINT          NULL,
    ReverseReason      NVARCHAR(200)   NULL,
    CreatedAtUtc       DATETIME2(3)    NOT NULL CONSTRAINT DF_Payments_Created DEFAULT (SYSUTCDATETIME()),
    CreatedBy          BIGINT          NULL,
    CONSTRAINT FK_Payments_Tenant  FOREIGN KEY (TenantId) REFERENCES dbo.tbl_Tenants (TenantId),
    CONSTRAINT FK_Payments_Profile FOREIGN KEY (BusinessProfileId) REFERENCES dbo.tbl_BusinessProfiles (BusinessProfileId),
    CONSTRAINT FK_Payments_Party   FOREIGN KEY (PartyId) REFERENCES dbo.tbl_Parties (PartyId),
    CONSTRAINT CK_Payments_Amount  CHECK (Amount >= 0 AND TdsAmount >= 0 AND Amount + TdsAmount > 0),
    CONSTRAINT CK_Payments_Mode    CHECK (Mode BETWEEN 1 AND 6),
    CONSTRAINT CK_Payments_Status  CHECK (Status IN (1, 2))
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Payments_List')
    CREATE INDEX IX_Payments_List ON dbo.tbl_Payments (TenantId, PaymentDate DESC) INCLUDE (PartyId, Amount, TdsAmount, Mode, Status, ReceiptNumber);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Payments_Party')
    CREATE INDEX IX_Payments_Party ON dbo.tbl_Payments (TenantId, PartyId) WHERE PartyId IS NOT NULL;
GO

IF OBJECT_ID('dbo.tbl_PaymentAllocations') IS NULL
CREATE TABLE dbo.tbl_PaymentAllocations
(
    PaymentAllocationId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PaymentAllocations PRIMARY KEY,
    PaymentId           BIGINT          NOT NULL,
    TenantId            BIGINT          NOT NULL,
    SalesInvoiceId      BIGINT          NOT NULL,
    Amount              DECIMAL(18,2)   NOT NULL,          -- money applied
    TdsAmount           DECIMAL(18,2)   NOT NULL CONSTRAINT DF_PaymentAllocations_Tds DEFAULT (0),
    IsActive            BIT             NOT NULL CONSTRAINT DF_PaymentAllocations_Active DEFAULT (1),
    AllocatedAtUtc      DATETIME2(3)    NOT NULL CONSTRAINT DF_PaymentAllocations_At DEFAULT (SYSUTCDATETIME()),
    AllocatedBy         BIGINT          NULL,
    CONSTRAINT FK_PaymentAllocations_Payment FOREIGN KEY (PaymentId) REFERENCES dbo.tbl_Payments (PaymentId),
    CONSTRAINT FK_PaymentAllocations_Invoice FOREIGN KEY (SalesInvoiceId) REFERENCES dbo.tbl_SalesInvoices (SalesInvoiceId),
    CONSTRAINT CK_PaymentAllocations_Amount CHECK (Amount >= 0 AND TdsAmount >= 0 AND Amount + TdsAmount > 0)
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_PaymentAllocations_Invoice')
    CREATE INDEX IX_PaymentAllocations_Invoice ON dbo.tbl_PaymentAllocations (SalesInvoiceId) INCLUDE (PaymentId, Amount, TdsAmount, IsActive);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_PaymentAllocations_Payment')
    CREATE INDEX IX_PaymentAllocations_Payment ON dbo.tbl_PaymentAllocations (PaymentId) INCLUDE (SalesInvoiceId, Amount, TdsAmount, IsActive);
GO

/* ============================================================================
   ALLOCATE (shared by record and apply-advance)

   Applies @Allocations (JSON: SalesInvoiceId, Amount, TdsAmount) from
   @PaymentId inside the caller's transaction. Returns a problem in words, or
   null. Locks each invoice so two people can't settle the same balance twice.
   ========================================================================= */
CREATE OR ALTER PROCEDURE dbo.usp_Payment_Allocate
    @TenantId       BIGINT,
    @PaymentId      BIGINT,
    @Allocations    NVARCHAR(MAX),
    @ActionByUserId BIGINT,
    @Problem        NVARCHAR(300) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @Problem = NULL;

    DECLARE @partyId BIGINT, @profileId BIGINT, @amount DECIMAL(18,2), @applied DECIMAL(18,2);
    SELECT @partyId = PartyId, @profileId = BusinessProfileId, @amount = Amount
      FROM dbo.tbl_Payments WHERE PaymentId = @PaymentId AND TenantId = @TenantId AND Status = 1;

    DECLARE @a TABLE (SalesInvoiceId BIGINT PRIMARY KEY, Amount DECIMAL(18,2), TdsAmount DECIMAL(18,2));
    INSERT INTO @a (SalesInvoiceId, Amount, TdsAmount)
    SELECT SalesInvoiceId, SUM(ISNULL(Amount, 0)), SUM(ISNULL(TdsAmount, 0))
      FROM OPENJSON(ISNULL(@Allocations, N'[]')) WITH (SalesInvoiceId BIGINT, Amount DECIMAL(18,2), TdsAmount DECIMAL(18,2))
     WHERE SalesInvoiceId IS NOT NULL
     GROUP BY SalesInvoiceId
    HAVING SUM(ISNULL(Amount, 0)) + SUM(ISNULL(TdsAmount, 0)) > 0;

    IF NOT EXISTS (SELECT 1 FROM @a) RETURN;

    IF EXISTS (SELECT 1 FROM @a WHERE Amount < 0 OR TdsAmount < 0)
    BEGIN SET @Problem = N'Amounts can''t be negative'; RETURN; END

    /* Lock the invoices being settled for the rest of the transaction. */
    DECLARE @inv TABLE (SalesInvoiceId BIGINT PRIMARY KEY, InvoiceNumber NVARCHAR(40), Balance DECIMAL(18,2),
                        Status TINYINT, PartyId BIGINT NULL, BusinessProfileId BIGINT);
    INSERT INTO @inv
    SELECT i.SalesInvoiceId, i.InvoiceNumber, i.GrandTotal - i.AmountPaid, i.Status, i.PartyId, i.BusinessProfileId
      FROM dbo.tbl_SalesInvoices i WITH (UPDLOCK, HOLDLOCK)
      JOIN @a a ON a.SalesInvoiceId = i.SalesInvoiceId
     WHERE i.TenantId = @TenantId;

    SELECT TOP (1) @Problem =
           CASE WHEN v.SalesInvoiceId IS NULL THEN N'An invoice in this payment no longer exists'
                WHEN v.Status <> 2 THEN CONCAT(ISNULL(v.InvoiceNumber, N'A draft'), N' is not an issued invoice')
                WHEN ISNULL(v.PartyId, -1) <> ISNULL(@partyId, -1) THEN CONCAT(v.InvoiceNumber, N' belongs to another customer')
                WHEN v.BusinessProfileId <> @profileId THEN CONCAT(v.InvoiceNumber, N' was issued by another of your businesses. Record a separate payment for it')
                WHEN a.Amount + a.TdsAmount > v.Balance THEN CONCAT(v.InvoiceNumber, N' has only ', FORMAT(v.Balance, 'N2', 'en-IN'), N' left to pay')
           END
      FROM @a a LEFT JOIN @inv v ON v.SalesInvoiceId = a.SalesInvoiceId
     WHERE v.SalesInvoiceId IS NULL OR v.Status <> 2 OR ISNULL(v.PartyId, -1) <> ISNULL(@partyId, -1)
        OR v.BusinessProfileId <> @profileId OR a.Amount + a.TdsAmount > v.Balance;
    IF @Problem IS NOT NULL RETURN;

    /* Money applied can't exceed money received (TDS was never received). */
    SELECT @applied = ISNULL(SUM(Amount), 0) FROM dbo.tbl_PaymentAllocations WHERE PaymentId = @PaymentId AND IsActive = 1;
    IF @applied + (SELECT SUM(Amount) FROM @a) > @amount
    BEGIN
        SET @Problem = CONCAT(N'Only ', FORMAT(@amount - @applied, 'N2', 'en-IN'), N' of this payment is left to apply');
        RETURN;
    END

    INSERT INTO dbo.tbl_PaymentAllocations (PaymentId, TenantId, SalesInvoiceId, Amount, TdsAmount, AllocatedBy)
    SELECT @PaymentId, @TenantId, SalesInvoiceId, Amount, TdsAmount, @ActionByUserId FROM @a;

    UPDATE i
       SET AmountPaid = i.AmountPaid + a.Amount + a.TdsAmount,
           TdsDeducted = i.TdsDeducted + a.TdsAmount,
           UpdatedAtUtc = SYSUTCDATETIME(), UpdatedBy = @ActionByUserId
      FROM dbo.tbl_SalesInvoices i JOIN @a a ON a.SalesInvoiceId = i.SalesInvoiceId;

    UPDATE dbo.tbl_Payments
       SET TdsAmount = (SELECT ISNULL(SUM(TdsAmount), 0) FROM dbo.tbl_PaymentAllocations WHERE PaymentId = @PaymentId AND IsActive = 1)
     WHERE PaymentId = @PaymentId;
END
GO

/* ============================================================================
   RECORD A PAYMENT
   ========================================================================= */
CREATE OR ALTER PROCEDURE dbo.usp_Payment_Record
    @TenantId          BIGINT,
    @BusinessProfileId BIGINT = NULL,      -- null: the default profile
    @PartyId           BIGINT = NULL,
    @PayerName         NVARCHAR(200) = NULL,
    @PaymentDate       DATE,
    @Amount            DECIMAL(18,2),
    @Mode              TINYINT,
    @Reference         NVARCHAR(60) = NULL,
    @InstrumentDate    DATE = NULL,
    @BankAccountId     BIGINT = NULL,
    @Notes             NVARCHAR(500) = NULL,
    @Allocations       NVARCHAR(MAX) = NULL,
    @Today             DATE,
    @ActionByUserId    BIGINT,
    @IpAddress         VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Reference = NULLIF(LTRIM(RTRIM(ISNULL(@Reference, ''))), '');
    SET @PayerName = NULLIF(LTRIM(RTRIM(ISNULL(@PayerName, ''))), '');

    IF @BusinessProfileId IS NULL
        SELECT @BusinessProfileId = BusinessProfileId FROM dbo.tbl_BusinessProfiles WHERE TenantId = @TenantId AND IsDefault = 1 AND IsActive = 1;

    /* With invoices chosen, the payment belongs to the business that issued them. */
    IF @Allocations IS NOT NULL
    BEGIN
        DECLARE @fromInvoices BIGINT = (SELECT TOP (1) i.BusinessProfileId FROM OPENJSON(@Allocations) WITH (SalesInvoiceId BIGINT) j
                                          JOIN dbo.tbl_SalesInvoices i ON i.SalesInvoiceId = j.SalesInvoiceId AND i.TenantId = @TenantId);
        IF @fromInvoices IS NOT NULL SET @BusinessProfileId = @fromInvoices;
    END

    IF @PartyId IS NOT NULL
    BEGIN
        SELECT @PayerName = LegalName FROM dbo.tbl_Parties WHERE PartyId = @PartyId AND TenantId = @TenantId;
        IF @PayerName IS NULL BEGIN SELECT ResultCode = 5, ResultMessage = N'That customer no longer exists', FieldName = 'PartyId'; RETURN; END
    END

    DECLARE @problem NVARCHAR(300) =
        CASE WHEN @PayerName IS NULL THEN N'Choose the customer who paid'
             WHEN @Amount IS NULL OR @Amount < 0 THEN N'Enter the amount received'
             WHEN @Amount = 0 AND (@Allocations IS NULL OR NOT EXISTS (SELECT 1 FROM OPENJSON(@Allocations) WITH (TdsAmount DECIMAL(18,2)) WHERE TdsAmount > 0))
                  THEN N'Enter the amount received'
             WHEN @PaymentDate > @Today THEN N'A payment can''t be dated in the future'
             WHEN @Mode NOT BETWEEN 1 AND 6 THEN N'Choose how it was paid'
             WHEN @BusinessProfileId IS NULL THEN N'Set up your business first'
             WHEN @BankAccountId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.tbl_BusinessBankAccounts WHERE BankAccountId = @BankAccountId AND TenantId = @TenantId)
                  THEN N'Choose one of your bank accounts'
             /* Income Tax Act s.269ST: no one may receive ₹2 lakh or more in cash from a person in a day.
                The penalty (s.271DA) equals the amount received, so the app refuses rather than warns. */
             WHEN @Mode = 1 AND @Amount + ISNULL((SELECT SUM(Amount) FROM dbo.tbl_Payments
                                                   WHERE TenantId = @TenantId AND Status = 1 AND Mode = 1 AND PaymentDate = @PaymentDate
                                                     AND (PartyId = @PartyId OR (@PartyId IS NULL AND PartyId IS NULL AND PayerName = @PayerName))), 0) >= 200000
                  THEN N'Cash of ₹2 lakh or more from one person in a day is not allowed (Income Tax Act s.269ST; the penalty equals the amount). Take the rest by bank transfer, UPI or cheque'
             /* The same UTR or cheque recorded twice is the commonest double count there is. */
             WHEN @Reference IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.tbl_Payments WHERE TenantId = @TenantId AND Status = 1 AND Reference = @Reference
                                                        AND ISNULL(PartyId, -1) = ISNULL(@PartyId, -1))
                  THEN CONCAT(N'Reference ', @Reference, N' is already recorded on ',
                              (SELECT TOP (1) ReceiptNumber FROM dbo.tbl_Payments WHERE TenantId = @TenantId AND Status = 1 AND Reference = @Reference
                                                        AND ISNULL(PartyId, -1) = ISNULL(@PartyId, -1)))
        END;
    IF @problem IS NOT NULL
    BEGIN
        SELECT ResultCode = 5, ResultMessage = @problem,
               FieldName = CASE WHEN @problem LIKE N'Reference%' THEN 'Reference' WHEN @problem LIKE N'Enter the amount%' OR @problem LIKE N'Cash of%' THEN 'Amount'
                                WHEN @problem LIKE N'A payment can%' THEN 'PaymentDate' WHEN @problem LIKE N'Choose the customer%' THEN 'PartyId' END;
        RETURN;
    END

    DECLARE @own BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    DECLARE @paymentId BIGINT, @number NVARCHAR(40), @numberId BIGINT, @seriesId BIGINT;

    BEGIN TRY
        IF @own = 1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION sp_payment_record;

        SELECT @seriesId = SeriesId FROM dbo.tbl_NumberSeries
         WHERE TenantId = @TenantId AND BusinessProfileId = @BusinessProfileId AND DocumentType = 7 AND IsDefault = 1 AND IsActive = 1;

        /* The first receipt creates the receipt series. */
        IF @seriesId IS NULL
        BEGIN
            DECLARE @prefix NVARCHAR(15) = N'RCT', @n INT = 2;
            WHILE EXISTS (SELECT 1 FROM dbo.tbl_NumberSeries WHERE TenantId = @TenantId AND DocumentType = 7 AND IsActive = 1 AND Prefix = @prefix)
            BEGIN SET @prefix = CONCAT(N'RCT', @n); SET @n += 1; END
            INSERT INTO dbo.tbl_NumberSeries (TenantId, BusinessProfileId, DocumentType, SeriesName, Prefix, PadWidth, Separator,
                                              YearFormat, ResetYearly, StartFrom, IsDefault, IsActive, CreatedAtUtc, CreatedBy)
            VALUES(@TenantId, @BusinessProfileId, 7, N'Receipts', @prefix, 4, N'-', 2, 1, 1, 1, 1, SYSUTCDATETIME(), @ActionByUserId);
            SET @seriesId = SCOPE_IDENTITY();
        END

        /* The number is taken here, in this transaction, so a failed save leaves no gap. */
        DECLARE @fy SMALLINT = dbo.fn_FinancialYear(@PaymentDate), @seq INT;
        DECLARE @sp NVARCHAR(15), @ss NVARCHAR(15), @sep NVARCHAR(3), @yf TINYINT, @pad TINYINT, @reset BIT, @start INT;
        SELECT @sp = Prefix, @ss = Suffix, @sep = Separator, @yf = YearFormat, @pad = PadWidth, @reset = ResetYearly, @start = StartFrom
          FROM dbo.tbl_NumberSeries WHERE SeriesId = @seriesId;
        DECLARE @counterYear SMALLINT = CASE WHEN @reset = 0 THEN 0 ELSE @fy END;

        SELECT @seq = NextNumber FROM dbo.tbl_NumberCounters WITH (UPDLOCK, HOLDLOCK) WHERE SeriesId = @seriesId AND FinancialYear = @counterYear;
        IF @seq IS NULL
        BEGIN
            SET @seq = @start;
            INSERT INTO dbo.tbl_NumberCounters (SeriesId, FinancialYear, NextNumber, LastIssuedUtc) VALUES(@seriesId, @counterYear, @start + 1, SYSUTCDATETIME());
        END
        ELSE
            UPDATE dbo.tbl_NumberCounters SET NextNumber = NextNumber + 1, LastIssuedUtc = SYSUTCDATETIME() WHERE SeriesId = @seriesId AND FinancialYear = @counterYear;

        SET @number = dbo.fn_FormatDocNumber(@sp, @ss, @sep, @yf, @fy, @seq, @pad);

        INSERT INTO dbo.tbl_Payments (TenantId, BusinessProfileId, PartyId, PayerName, SeriesId, ReceiptNumber, PaymentDate, Amount, Mode,
                                      Reference, InstrumentDate, BankAccountId, Notes, CreatedBy)
        VALUES(@TenantId, @BusinessProfileId, @PartyId, @PayerName, @seriesId, @number, @PaymentDate, @Amount, @Mode,
               @Reference, @InstrumentDate, @BankAccountId, NULLIF(LTRIM(RTRIM(ISNULL(@Notes, ''))), ''), @ActionByUserId);
        SET @paymentId = SCOPE_IDENTITY();

        INSERT INTO dbo.tbl_IssuedNumbers (TenantId, SeriesId, FinancialYear, SequenceNumber, FullNumber, DocumentType, DocumentId, DocumentDate, IssuedBy)
        VALUES(@TenantId, @seriesId, @counterYear, @seq, @number, 7, @paymentId, @PaymentDate, @ActionByUserId);
        SET @numberId = SCOPE_IDENTITY();
        UPDATE dbo.tbl_Payments SET IssuedNumberId = @numberId WHERE PaymentId = @paymentId;

        EXEC dbo.usp_Payment_Allocate @TenantId = @TenantId, @PaymentId = @paymentId, @Allocations = @Allocations,
                                      @ActionByUserId = @ActionByUserId, @Problem = @problem OUTPUT;
        IF @problem IS NOT NULL
        BEGIN
            IF @own = 1 ROLLBACK TRANSACTION; ELSE ROLLBACK TRANSACTION sp_payment_record;
            SELECT ResultCode = 5, ResultMessage = @problem, FieldName = CONVERT(VARCHAR(40), NULL);
            RETURN;
        END

        INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, IpAddress)
        VALUES(@TenantId, @ActionByUserId, 'Payment.Recorded', 'Payment', @paymentId, @number,
               CONCAT(N'Received ₹', FORMAT(@Amount, 'N2', 'en-IN'), N' from ', @PayerName, N' (', @number, N')'), @IpAddress);

        IF @own = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @own = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok', FieldName = CONVERT(VARCHAR(40), NULL), PaymentId = @paymentId, ReceiptNumber = @number;
END
GO

/* Apply an advance (the unallocated part of a payment) to invoices. */
CREATE OR ALTER PROCEDURE dbo.usp_Payment_Apply
    @TenantId       BIGINT,
    @PaymentId      BIGINT,
    @Allocations    NVARCHAR(MAX),
    @ActionByUserId BIGINT,
    @IpAddress      VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.tbl_Payments WHERE PaymentId = @PaymentId AND TenantId = @TenantId AND Status = 1)
    BEGIN SELECT ResultCode = 1, ResultMessage = N'That payment no longer exists or was reversed'; RETURN; END

    DECLARE @problem NVARCHAR(300), @own BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    BEGIN TRY
        IF @own = 1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION sp_payment_apply;
        DECLARE @lock BIT;
        SELECT @lock = 1 FROM dbo.tbl_Payments WITH (UPDLOCK) WHERE PaymentId = @PaymentId;

        EXEC dbo.usp_Payment_Allocate @TenantId = @TenantId, @PaymentId = @PaymentId, @Allocations = @Allocations,
                                      @ActionByUserId = @ActionByUserId, @Problem = @problem OUTPUT;
        IF @problem IS NOT NULL
        BEGIN
            IF @own = 1 ROLLBACK TRANSACTION; ELSE ROLLBACK TRANSACTION sp_payment_apply;
            SELECT ResultCode = 5, ResultMessage = @problem;
            RETURN;
        END

        INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, IpAddress)
        SELECT @TenantId, @ActionByUserId, 'Payment.AdvanceApplied', 'Payment', @PaymentId, ReceiptNumber,
               CONCAT(N'Applied advance from ', ReceiptNumber, N' to invoices'), @IpAddress
          FROM dbo.tbl_Payments WHERE PaymentId = @PaymentId;

        IF @own = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @own = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok';
END
GO

/* Reverse a payment: a bounced cheque, a payment recorded against the wrong customer. */
CREATE OR ALTER PROCEDURE dbo.usp_Payment_Reverse
    @TenantId       BIGINT,
    @PaymentId      BIGINT,
    @Reason         NVARCHAR(200),
    @ActionByUserId BIGINT,
    @IpAddress      VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Reason = NULLIF(LTRIM(RTRIM(ISNULL(@Reason, ''))), '');
    DECLARE @status TINYINT, @number NVARCHAR(40), @amount DECIMAL(18,2), @payer NVARCHAR(200);
    SELECT @status = Status, @number = ReceiptNumber, @amount = Amount, @payer = PayerName
      FROM dbo.tbl_Payments WHERE PaymentId = @PaymentId AND TenantId = @TenantId;

    IF @status IS NULL BEGIN SELECT ResultCode = 1, ResultMessage = N'That payment no longer exists'; RETURN; END
    IF @status = 2 BEGIN SELECT ResultCode = 5, ResultMessage = N'This payment is already reversed'; RETURN; END
    IF @Reason IS NULL OR LEN(@Reason) < 3 BEGIN SELECT ResultCode = 5, ResultMessage = N'Say why it is being reversed (e.g. cheque bounced). The reason stays on record'; RETURN; END

    DECLARE @own BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    BEGIN TRY
        IF @own = 1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION sp_payment_reverse;

        UPDATE i
           SET AmountPaid = i.AmountPaid - a.Amount - a.TdsAmount,
               TdsDeducted = i.TdsDeducted - a.TdsAmount,
               UpdatedAtUtc = SYSUTCDATETIME(), UpdatedBy = @ActionByUserId
          FROM dbo.tbl_SalesInvoices i WITH (UPDLOCK)
          JOIN (SELECT SalesInvoiceId, Amount = SUM(Amount), TdsAmount = SUM(TdsAmount)
                  FROM dbo.tbl_PaymentAllocations WHERE PaymentId = @PaymentId AND IsActive = 1 GROUP BY SalesInvoiceId) a
            ON a.SalesInvoiceId = i.SalesInvoiceId;

        UPDATE dbo.tbl_PaymentAllocations SET IsActive = 0 WHERE PaymentId = @PaymentId AND IsActive = 1;

        UPDATE dbo.tbl_Payments
           SET Status = 2, ReversedAtUtc = SYSUTCDATETIME(), ReversedBy = @ActionByUserId, ReverseReason = @Reason
         WHERE PaymentId = @PaymentId;

        UPDATE dbo.tbl_IssuedNumbers SET IsCancelled = 1, CancelledAtUtc = SYSUTCDATETIME(), CancelReason = @Reason
         WHERE TenantId = @TenantId AND DocumentType = 7 AND DocumentId = @PaymentId;

        INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, IpAddress)
        VALUES(@TenantId, @ActionByUserId, 'Payment.Reversed', 'Payment', @PaymentId, @number,
               CONCAT(N'Reversed ', @number, N' (₹', FORMAT(@amount, 'N2', 'en-IN'), N' from ', @payer, N'): ', @Reason), @IpAddress);

        IF @own = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @own = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok';
END
GO

/* What a customer owes, oldest first, and any advance they have with you. */
CREATE OR ALTER PROCEDURE dbo.usp_Payment_OpenInvoices
    @TenantId BIGINT,
    @PartyId  BIGINT,
    @Today    DATE
AS
BEGIN
    SET NOCOUNT ON;

    SELECT i.SalesInvoiceId, i.InvoiceNumber, i.InvoiceDate, i.DueDate, i.GrandTotal, i.AmountPaid,
           Balance = i.GrandTotal - i.AmountPaid, i.BusinessProfileId,
           DaysOverdue = CASE WHEN i.DueDate < @Today THEN DATEDIFF(DAY, i.DueDate, @Today) END
      FROM dbo.tbl_SalesInvoices i
     WHERE i.TenantId = @TenantId AND i.PartyId = @PartyId AND i.Status = 2 AND i.GrandTotal > i.AmountPaid
     ORDER BY i.InvoiceDate, i.SalesInvoiceId;

    SELECT p.PaymentId, p.ReceiptNumber, p.PaymentDate, p.Amount,
           Unapplied = p.Amount - ISNULL((SELECT SUM(a.Amount) FROM dbo.tbl_PaymentAllocations a WHERE a.PaymentId = p.PaymentId AND a.IsActive = 1), 0)
      FROM dbo.tbl_Payments p
     WHERE p.TenantId = @TenantId AND p.PartyId = @PartyId AND p.Status = 1
       AND p.Amount > ISNULL((SELECT SUM(a.Amount) FROM dbo.tbl_PaymentAllocations a WHERE a.PaymentId = p.PaymentId AND a.IsActive = 1), 0)
     ORDER BY p.PaymentDate, p.PaymentId;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_Payment_Get
    @TenantId  BIGINT,
    @PaymentId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT p.*, Applied = ISNULL(a.Applied, 0), Unapplied = p.Amount - ISNULL(a.Applied, 0),
           b.BankName, BankAccountNumber = b.AccountNumber, CreatedByName = cu.FullName, ReversedByName = ru.FullName
      FROM dbo.tbl_Payments p
      LEFT JOIN (SELECT PaymentId, Applied = SUM(Amount) FROM dbo.tbl_PaymentAllocations WHERE IsActive = 1 GROUP BY PaymentId) a ON a.PaymentId = p.PaymentId
      LEFT JOIN dbo.tbl_BusinessBankAccounts b ON b.BankAccountId = p.BankAccountId
      LEFT JOIN dbo.tbl_Users cu ON cu.UserId = p.CreatedBy
      LEFT JOIN dbo.tbl_Users ru ON ru.UserId = p.ReversedBy
     WHERE p.PaymentId = @PaymentId AND p.TenantId = @TenantId;

    SELECT a.PaymentAllocationId, a.SalesInvoiceId, i.InvoiceNumber, i.InvoiceDate, i.GrandTotal, a.Amount, a.TdsAmount, a.IsActive, a.AllocatedAtUtc
      FROM dbo.tbl_PaymentAllocations a
      JOIN dbo.tbl_SalesInvoices i ON i.SalesInvoiceId = a.SalesInvoiceId
     WHERE a.PaymentId = @PaymentId AND a.TenantId = @TenantId
     ORDER BY i.InvoiceDate, a.PaymentAllocationId;
END
GO

/* Receipts against one invoice, for its history. */
CREATE OR ALTER PROCEDURE dbo.usp_Payment_ForInvoice
    @TenantId       BIGINT,
    @SalesInvoiceId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.PaymentId, p.ReceiptNumber, p.PaymentDate, p.Mode, p.Reference, p.Status, p.ReverseReason,
           a.Amount, a.TdsAmount, a.IsActive
      FROM dbo.tbl_PaymentAllocations a
      JOIN dbo.tbl_Payments p ON p.PaymentId = a.PaymentId
     WHERE a.SalesInvoiceId = @SalesInvoiceId AND a.TenantId = @TenantId
     ORDER BY p.PaymentDate, p.PaymentId;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_Payment_List
    @TenantId BIGINT,
    @View     VARCHAR(12) = 'all',     -- all, advance, reversed
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
        SELECT p.PaymentId, p.ReceiptNumber, p.PaymentDate, p.PartyId, p.PayerName, p.Amount, p.TdsAmount, p.Mode, p.Reference, p.Status,
               Unapplied = CASE WHEN p.Status = 1 THEN p.Amount - ISNULL(a.Applied, 0) ELSE 0 END,
               Invoices = STUFF((SELECT N', ' + i.InvoiceNumber FROM dbo.tbl_PaymentAllocations x
                                   JOIN dbo.tbl_SalesInvoices i ON i.SalesInvoiceId = x.SalesInvoiceId
                                  WHERE x.PaymentId = p.PaymentId AND x.IsActive = 1 ORDER BY i.InvoiceDate
                                    FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, N'')
          FROM dbo.tbl_Payments p
          LEFT JOIN (SELECT PaymentId, Applied = SUM(Amount) FROM dbo.tbl_PaymentAllocations WHERE IsActive = 1 GROUP BY PaymentId) a ON a.PaymentId = p.PaymentId
         WHERE p.TenantId = @TenantId
           AND (@PartyId IS NULL OR p.PartyId = @PartyId)
           AND (@Search IS NULL OR p.ReceiptNumber LIKE @like OR p.PayerName LIKE @like OR p.Reference LIKE @like
                OR EXISTS (SELECT 1 FROM dbo.tbl_PaymentAllocations x JOIN dbo.tbl_SalesInvoices i ON i.SalesInvoiceId = x.SalesInvoiceId
                            WHERE x.PaymentId = p.PaymentId AND i.InvoiceNumber LIKE @like))
    )
    SELECT *, Total = COUNT(*) OVER ()
      FROM v
     WHERE @View = 'all' OR (@View = 'advance' AND Unapplied > 0) OR (@View = 'reversed' AND Status = 2)
     ORDER BY PaymentDate DESC, PaymentId DESC
    OFFSET (@Page - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    DECLARE @monthStart DATE = DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1);
    SELECT ReceivedThisMonth = ISNULL(SUM(CASE WHEN p.Status = 1 AND p.PaymentDate >= @monthStart THEN p.Amount END), 0),
           TdsThisMonth = ISNULL(SUM(CASE WHEN p.Status = 1 AND p.PaymentDate >= @monthStart THEN p.TdsAmount END), 0),
           ReceivedToday = ISNULL(SUM(CASE WHEN p.Status = 1 AND p.PaymentDate = @Today THEN p.Amount END), 0),
           CashThisMonth = ISNULL(SUM(CASE WHEN p.Status = 1 AND p.Mode = 1 AND p.PaymentDate >= @monthStart THEN p.Amount END), 0),
           Advances = ISNULL(SUM(CASE WHEN p.Status = 1 THEN p.Amount - ISNULL(a.Applied, 0) END), 0)
      FROM dbo.tbl_Payments p
      LEFT JOIN (SELECT PaymentId, Applied = SUM(Amount) FROM dbo.tbl_PaymentAllocations WHERE IsActive = 1 GROUP BY PaymentId) a ON a.PaymentId = p.PaymentId
     WHERE p.TenantId = @TenantId AND (@PartyId IS NULL OR p.PartyId = @PartyId);
END
GO
