/*  34 · Catalog starting point, and customer-specific prices.

    1. Every business gets standard GST rates and GST units (UQC) — new ones automatically,
       existing ones now if they have none. Without them nobody can raise an invoice.
       Rates follow the rationalisation effective 22 Sep 2025: 5%, 18%, 40% plus 0.25% and 3%;
       12% and 28% are kept with an end date for older invoices (a business that still needs
       one can clear the end date).
    2. Customer prices: "FreshBite pays ₹25,000 for this". Stored as a price list for the party,
       which usp_Price_Resolve already ranks first.
    Idempotent.  */

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* @Silent = 1 from the trigger: a trigger must never add a result set to the statement that
   fired it (usp_Setup_ProvisionTenant's caller reads the first one it gets). */
CREATE OR ALTER PROCEDURE dbo.usp_Catalog_EnsureDefaults
    @TenantId BIGINT,
    @Silent   BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    /* TaxType: 1 GST, 2 Nil rated, 3 Exempt, 4 Non-GST, 5 Zero rated (exports, SEZ). */
    IF NOT EXISTS (SELECT 1 FROM dbo.tbl_TaxRates WHERE TenantId = @TenantId)
        INSERT INTO dbo.tbl_TaxRates (TenantId, TaxName, TaxType, RatePercent, CessPercent, EffectiveFrom, EffectiveTo, IsDefault, IsActive)
        VALUES (@TenantId, N'GST 18%',   1, 18,   0, '2017-07-01', NULL,         1, 1),
               (@TenantId, N'GST 5%',    1, 5,    0, '2017-07-01', NULL,         0, 1),
               (@TenantId, N'GST 40%',   1, 40,   0, '2025-09-22', NULL,         0, 1),
               (@TenantId, N'GST 3%',    1, 3,    0, '2017-07-01', NULL,         0, 1),
               (@TenantId, N'GST 0.25%', 1, 0.25, 0, '2017-07-01', NULL,         0, 1),
               (@TenantId, N'GST 12%',   1, 12,   0, '2017-07-01', '2025-09-21', 0, 1),
               (@TenantId, N'GST 28%',   1, 28,   0, '2017-07-01', '2025-09-21', 0, 1),
               (@TenantId, N'Nil rated', 2, 0,    0, '2017-07-01', NULL,         0, 1),
               (@TenantId, N'Exempt',    3, 0,    0, '2017-07-01', NULL,         0, 1),
               (@TenantId, N'Non-GST',   4, 0,    0, '2017-07-01', NULL,         0, 1),
               (@TenantId, N'Zero rated (export / SEZ)', 5, 0, 0, '2017-07-01', NULL, 0, 1);

    /* UqcCode is the GST unit printed on e-invoices and e-way bills. */
    IF NOT EXISTS (SELECT 1 FROM dbo.tbl_Units WHERE TenantId = @TenantId)
        INSERT INTO dbo.tbl_Units (TenantId, UnitName, UnitCode, UqcCode, DecimalPlaces, IsActive, SortOrder)
        VALUES (@TenantId, N'Piece', N'pc', 'PCS', 0, 1, 10),       (@TenantId, N'Number', N'no', 'NOS', 0, 1, 20),
               (@TenantId, N'Set', N'set', 'SET', 0, 1, 30),        (@TenantId, N'Pair', N'pr', 'PRS', 0, 1, 40),
               (@TenantId, N'Box', N'box', 'BOX', 0, 1, 50),        (@TenantId, N'Carton', N'ctn', 'CTN', 0, 1, 55),
               (@TenantId, N'Pack', N'pack', 'PAC', 0, 1, 56),      (@TenantId, N'Dozen', N'doz', 'DOZ', 0, 1, 57),
               (@TenantId, N'Bottle', N'btl', 'BTL', 0, 1, 58),     (@TenantId, N'Bag', N'bag', 'BAG', 0, 1, 59),
               (@TenantId, N'Roll', N'roll', 'ROL', 0, 1, 60),
               (@TenantId, N'Kilogram', N'kg', 'KGS', 3, 1, 70),    (@TenantId, N'Gram', N'g', 'GMS', 3, 1, 80),
               (@TenantId, N'Quintal', N'qtl', 'QTL', 3, 1, 85),    (@TenantId, N'Tonne', N't', 'TON', 3, 1, 86),
               (@TenantId, N'Litre', N'l', 'LTR', 3, 1, 90),        (@TenantId, N'Millilitre', N'ml', 'MLT', 0, 1, 95),
               (@TenantId, N'Metre', N'm', 'MTR', 2, 1, 100),       (@TenantId, N'Square metre', N'sqm', 'SQM', 2, 1, 105),
               (@TenantId, N'Square foot', N'sqft', 'SQF', 2, 1, 110),
               (@TenantId, N'Hour', N'hr', 'OTH', 2, 1, 200),       (@TenantId, N'Day', N'day', 'OTH', 2, 1, 210),
               (@TenantId, N'Month', N'mo', 'OTH', 2, 1, 220),      (@TenantId, N'Year', N'yr', 'OTH', 2, 1, 230),
               (@TenantId, N'Service', N'svc', 'OTH', 2, 1, 240);

    IF @Silent = 0
        SELECT ResultCode = 0, ResultMessage = N'Ok';
END
GO

/* New businesses, from either app, get the defaults the moment they are created. */
CREATE OR ALTER TRIGGER dbo.trg_Tenants_CatalogDefaults ON dbo.tbl_Tenants
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
        EXEC dbo.usp_Catalog_EnsureDefaults @TenantId = @id, @Silent = 1;
        FETCH NEXT FROM c INTO @id;
    END
    CLOSE c;
    DEALLOCATE c;
END
GO

/* Existing businesses that have none yet. */
DECLARE @t BIGINT;
DECLARE existing CURSOR LOCAL FAST_FORWARD FOR SELECT TenantId FROM dbo.tbl_Tenants;
OPEN existing;
FETCH NEXT FROM existing INTO @t;
WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC dbo.usp_Catalog_EnsureDefaults @TenantId = @t, @Silent = 1;
    FETCH NEXT FROM existing INTO @t;
END
CLOSE existing;
DEALLOCATE existing;
GO

/* ── Customer prices ─────────────────────────────────────────────────────── */

/* What each customer pays for one item, highest quantity break last. */
CREATE OR ALTER PROCEDURE dbo.usp_PartyPrice_List
    @TenantId   BIGINT,
    @OfferingId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT pi.PriceListItemId, pl.PartyId, PartyName = p.DisplayName,
           pi.MinQuantity, pi.Price, pi.DiscountPercent,
           pl.EffectiveFrom, pl.EffectiveTo, pi.UpdatedAtUtc, pi.CreatedAtUtc
      FROM dbo.tbl_PriceListItems pi
     INNER JOIN dbo.tbl_PriceLists pl ON pl.PriceListId = pi.PriceListId AND pl.IsActive = 1
     INNER JOIN dbo.tbl_Parties p     ON p.PartyId = pl.PartyId
     WHERE pi.TenantId = @TenantId AND pi.OfferingId = @OfferingId AND pi.IsActive = 1
       AND pl.PartyId IS NOT NULL
     ORDER BY p.DisplayName, pi.MinQuantity;
END
GO

/* Sets the price (or a discount off the default) this customer pays from @MinQuantity up.
   The customer's own price list is created on first use. */
CREATE OR ALTER PROCEDURE dbo.usp_PartyPrice_Set
    @TenantId        BIGINT,
    @OfferingId      BIGINT,
    @PartyId         BIGINT,
    @MinQuantity     DECIMAL(18,4) = 1,
    @Price           DECIMAL(18,4) = NULL,
    @DiscountPercent DECIMAL(9,4)  = NULL,
    @ActionByUserId  BIGINT,
    @IpAddress       VARCHAR(45)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF (@Price IS NULL AND @DiscountPercent IS NULL) OR (@Price IS NOT NULL AND @DiscountPercent IS NOT NULL)
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'Give either a price or a discount', FieldName = 'Price';
        RETURN;
    END
    IF @Price < 0 OR @DiscountPercent < 0 OR @DiscountPercent > 100
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'That amount isn''t possible', FieldName = 'Price';
        RETURN;
    END
    IF @MinQuantity IS NULL OR @MinQuantity <= 0 SET @MinQuantity = 1;

    DECLARE @partyName NVARCHAR(150), @offeringName NVARCHAR(200);
    SELECT @partyName = DisplayName FROM dbo.tbl_Parties WHERE PartyId = @PartyId AND TenantId = @TenantId AND IsActive = 1;
    SELECT @offeringName = OfferingName FROM dbo.tbl_Offerings WHERE OfferingId = @OfferingId AND TenantId = @TenantId;
    IF @partyName IS NULL OR @offeringName IS NULL
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'That customer or item no longer exists';
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @listId BIGINT;
        SELECT TOP (1) @listId = PriceListId FROM dbo.tbl_PriceLists WITH (UPDLOCK)
         WHERE TenantId = @TenantId AND PartyId = @PartyId AND IsActive = 1
         ORDER BY Priority DESC, PriceListId;

        IF @listId IS NULL
        BEGIN
            INSERT INTO dbo.tbl_PriceLists (TenantId, ListName, PartyId, CurrencyCode, Priority, CreatedBy)
            VALUES (@TenantId, LEFT(CONCAT(N'Agreed prices · ', @partyName), 80), @PartyId, 'INR', 100, @ActionByUserId);
            SET @listId = SCOPE_IDENTITY();
        END

        DECLARE @old DECIMAL(18,4), @oldPct DECIMAL(9,4);
        SELECT @old = Price, @oldPct = DiscountPercent FROM dbo.tbl_PriceListItems
         WHERE PriceListId = @listId AND OfferingId = @OfferingId AND MinQuantity = @MinQuantity AND IsActive = 1;

        UPDATE dbo.tbl_PriceListItems
           SET Price = @Price, DiscountPercent = @DiscountPercent, UpdatedAtUtc = SYSUTCDATETIME(), UpdatedBy = @ActionByUserId
         WHERE PriceListId = @listId AND OfferingId = @OfferingId AND MinQuantity = @MinQuantity AND IsActive = 1;
        IF @@ROWCOUNT = 0
            INSERT INTO dbo.tbl_PriceListItems (TenantId, PriceListId, OfferingId, MinQuantity, Price, DiscountPercent, CreatedBy)
            VALUES (@TenantId, @listId, @OfferingId, @MinQuantity, @Price, @DiscountPercent, @ActionByUserId);

        INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, OldValues, NewValues, IpAddress)
        VALUES (@TenantId, @ActionByUserId, 'Catalog.CustomerPriceSet', 'Offering', @OfferingId, @offeringName,
                CONCAT(N'Price for ', @partyName, N' from ', FORMAT(@MinQuantity, 'G29'), N' units'),
                COALESCE(CONVERT(NVARCHAR(40), @old), CONCAT(CONVERT(NVARCHAR(40), @oldPct), N'%')),
                COALESCE(CONVERT(NVARCHAR(40), @Price), CONCAT(CONVERT(NVARCHAR(40), @DiscountPercent), N'%')), @IpAddress);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok';
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_PartyPrice_Remove
    @TenantId        BIGINT,
    @PriceListItemId BIGINT,
    @ActionByUserId  BIGINT,
    @IpAddress       VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.tbl_PriceListItems
       SET IsActive = 0, UpdatedAtUtc = SYSUTCDATETIME(), UpdatedBy = @ActionByUserId
     WHERE PriceListItemId = @PriceListItemId AND TenantId = @TenantId AND IsActive = 1;
    IF @@ROWCOUNT = 0
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'That price no longer exists';
        RETURN;
    END
    INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, Summary, IpAddress)
    VALUES (@TenantId, @ActionByUserId, 'Catalog.CustomerPriceRemoved', 'PriceListItem', @PriceListItemId, N'Customer price removed', @IpAddress);
    SELECT ResultCode = 0, ResultMessage = N'Ok';
END
GO
