/* 35 · Catalogue: a duplicate barcode is a sentence, not a crash
   ------------------------------------------------------------------
   usp_Offering_Save let a second product take a barcode already in use, and
   the unique index then threw. Now the procedure checks first and names the
   item that has the code. A product changed to a service or expense also
   drops its barcode and pack size (unless stock has been tracked against it).
   Safe to run more than once. */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_Offering_Save]
    @TenantId        BIGINT,
    @OfferingId      BIGINT        = 0,
    @OfferingType    TINYINT       = 1,
    @OfferingName    NVARCHAR(200),
    @OfferingCode    NVARCHAR(40)  = NULL,
    @Description     NVARCHAR(1000) = NULL,
    @CategoryId      BIGINT        = NULL,
    @BrandName       NVARCHAR(80)  = NULL,
    @UnitId          BIGINT        = NULL,
    @TaxRateId       BIGINT        = NULL,
    @DefaultPrice    DECIMAL(18,4) = NULL,
    @DefaultCost     DECIMAL(18,4) = NULL,
    @IsPriceInclusive BIT          = 0,
    @IsPureAgent     BIT           = 0,
    @HsnSacCode      VARCHAR(10)   = NULL,
    @IsRecurring     BIT           = 0,
    @IsSellable      BIT           = 1,
    @IsPurchasable   BIT           = 0,

    @Barcode         NVARCHAR(50)  = NULL,
    @PackSize        NVARCHAR(40)  = NULL,
    @TracksStock     BIT           = 0,
    @ReorderLevel    DECIMAL(18,4) = NULL,

    @ActionByUserId  BIGINT,
    @IpAddress       VARCHAR(45)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @isNew BIT = CASE WHEN @OfferingId > 0 THEN 0 ELSE 1 END;
    DECLARE @brandId BIGINT = NULL, @oldName NVARCHAR(200);

    SET @OfferingName = LTRIM(RTRIM(ISNULL(@OfferingName, '')));
    SET @OfferingCode = NULLIF(LTRIM(RTRIM(ISNULL(@OfferingCode, ''))), '');
    SET @BrandName    = NULLIF(LTRIM(RTRIM(ISNULL(@BrandName, ''))), '');
    SET @HsnSacCode   = NULLIF(LTRIM(RTRIM(ISNULL(@HsnSacCode, ''))), '');

    IF LEN(@OfferingName) < 2
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'Enter a name', FieldName = 'OfferingName';
        RETURN;
    END

    /* Rule 33 again: a pure-agent recovery sits outside the value of supply, so
       it cannot also carry a tax rate. The check constraint would throw; saying
       so plainly is better. */
    IF @IsPureAgent = 1 AND @TaxRateId IS NOT NULL
    BEGIN
        SELECT ResultCode = 5,
               ResultMessage = N'A pure-agent reimbursement is outside GST, so it can''t have a tax rate',
               FieldName = 'TaxRateId';
        RETURN;
    END

    IF @OfferingCode IS NOT NULL AND EXISTS
       (SELECT 1 FROM dbo.tbl_Offerings
         WHERE TenantId = @TenantId AND OfferingCode = @OfferingCode
           AND IsActive = 1 AND OfferingId <> @OfferingId)
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'That code is already used', FieldName = 'OfferingCode';
        RETURN;
    END

    /* A barcode identifies one product. Scanning it at the counter must find
       exactly one item, so a second item with the same code is refused, and the
       message names the item that has it (it may be hidden). */
    SET @Barcode = NULLIF(LTRIM(RTRIM(ISNULL(@Barcode, ''))), '');
    IF @OfferingType = 1 AND @Barcode IS NOT NULL
    BEGIN
        DECLARE @barcodeOwner NVARCHAR(200), @barcodeOwnerActive BIT;
        SELECT TOP (1) @barcodeOwner = o.OfferingName, @barcodeOwnerActive = o.IsActive
          FROM dbo.tbl_ProductDetails d
         INNER JOIN dbo.tbl_Offerings o ON o.OfferingId = d.OfferingId
         WHERE d.TenantId = @TenantId AND d.Barcode = @Barcode AND d.OfferingId <> @OfferingId;

        IF @barcodeOwner IS NOT NULL
        BEGIN
            SELECT ResultCode = 5,
                   ResultMessage = CONCAT(N'That barcode is already on ', @barcodeOwner,
                                          CASE WHEN @barcodeOwnerActive = 0 THEN N' (hidden)' ELSE N'' END),
                   FieldName = 'Barcode';
            RETURN;
        END
    END

    IF @UnitId IS NOT NULL AND NOT EXISTS
       (SELECT 1 FROM dbo.tbl_Units WHERE UnitId = @UnitId AND TenantId = @TenantId AND IsActive = 1)
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'That unit does not belong to this business';
        RETURN;
    END

    IF @TaxRateId IS NOT NULL AND NOT EXISTS
       (SELECT 1 FROM dbo.tbl_TaxRates WHERE TaxRateId = @TaxRateId AND TenantId = @TenantId AND IsActive = 1)
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'That tax rate does not belong to this business';
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        /* ── Brand: match, or promote ──
           Matching is on the normalised name, so "M.R.F." finds the existing
           "MRF" rather than adding a second row that reports would then split
           across. */
        IF @BrandName IS NOT NULL
        BEGIN
            DECLARE @searchName NVARCHAR(80) =
                UPPER(REPLACE(REPLACE(REPLACE(@BrandName, '.', ''), '-', ''), ' ', ''));

            SELECT @brandId = ProductBrandId FROM dbo.tbl_ProductBrands
             WHERE TenantId = @TenantId AND SearchName = @searchName AND IsActive = 1;

            IF @brandId IS NULL
            BEGIN
                INSERT INTO dbo.tbl_ProductBrands (TenantId, BrandName, CreatedBy)
                VALUES(@TenantId, @BrandName, @ActionByUserId);

                SET @brandId = SCOPE_IDENTITY();
            END
        END

        IF @isNew = 1
        BEGIN
            INSERT INTO dbo.tbl_Offerings
                  (TenantId, OfferingType, OfferingName, OfferingCode, Description,
                   CategoryId, ProductBrandId, UnitId, TaxRateId,
                   DefaultPrice, DefaultCost, IsPriceInclusive, IsPureAgent,
                   HsnSacCode, IsRecurring, IsSellable, IsPurchasable, CreatedBy)
            VALUES(@TenantId, @OfferingType, @OfferingName, @OfferingCode, @Description,
                   @CategoryId, @brandId, @UnitId, @TaxRateId,
                   @DefaultPrice, @DefaultCost, @IsPriceInclusive, @IsPureAgent,
                   @HsnSacCode, @IsRecurring, @IsSellable, @IsPurchasable, @ActionByUserId);

            SET @OfferingId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            SELECT @oldName = OfferingName FROM dbo.tbl_Offerings
             WHERE OfferingId = @OfferingId AND TenantId = @TenantId;

            IF @oldName IS NULL
            BEGIN
                ROLLBACK TRANSACTION;
                SELECT ResultCode = 1, ResultMessage = N'That item no longer exists';
                RETURN;
            END

            UPDATE dbo.tbl_Offerings
               SET OfferingType = @OfferingType, OfferingName = @OfferingName,
                   OfferingCode = @OfferingCode, Description = @Description,
                   CategoryId = @CategoryId, ProductBrandId = @brandId,
                   UnitId = @UnitId, TaxRateId = @TaxRateId,
                   DefaultPrice = @DefaultPrice, DefaultCost = @DefaultCost,
                   IsPriceInclusive = @IsPriceInclusive, IsPureAgent = @IsPureAgent,
                   HsnSacCode = @HsnSacCode, IsRecurring = @IsRecurring,
                   IsSellable = @IsSellable, IsPurchasable = @IsPurchasable,
                   UpdatedAtUtc = @now, UpdatedBy = @ActionByUserId
             WHERE OfferingId = @OfferingId AND TenantId = @TenantId;
        END

        /* ── Product detail, only for products ──
           A row is written when there is something to put in it, so a service
           never grows an empty stock record. */
        IF @OfferingType <> 1
            DELETE FROM dbo.tbl_ProductDetails
             WHERE OfferingId = @OfferingId AND TenantId = @TenantId AND TracksStock = 0;

        IF @OfferingType = 1 AND (@Barcode IS NOT NULL OR @PackSize IS NOT NULL OR @TracksStock = 1)
        BEGIN
            UPDATE dbo.tbl_ProductDetails
               SET Barcode = @Barcode, PackSize = @PackSize, TracksStock = @TracksStock,
                   ReorderLevel = @ReorderLevel, UpdatedAtUtc = @now, UpdatedBy = @ActionByUserId
             WHERE OfferingId = @OfferingId;

            IF @@ROWCOUNT = 0
                INSERT INTO dbo.tbl_ProductDetails
                      (OfferingId, TenantId, Barcode, PackSize, TracksStock, ReorderLevel)
                VALUES(@OfferingId, @TenantId, @Barcode, @PackSize, @TracksStock, @ReorderLevel);
        END

        INSERT INTO dbo.tbl_AuditLog
              (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, OldValues, NewValues, IpAddress)
        VALUES(@TenantId, @ActionByUserId,
               CASE WHEN @isNew = 1 THEN 'Catalog.Created' ELSE 'Catalog.Updated' END,
               'Offering', @OfferingId, @OfferingName,
               CASE WHEN @isNew = 1 THEN CONCAT(N'Added ', @OfferingName) ELSE CONCAT(N'Updated ', @OfferingName) END,
               @oldName, @OfferingName, @IpAddress);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok', OfferingId = @OfferingId, IsNew = @isNew;
END
GO
