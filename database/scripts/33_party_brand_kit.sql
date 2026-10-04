/*  33 · Brand kit: everything a designer needs to produce work for a client's brand.
    Logo (light and dark backgrounds), named colours, fonts, tagline, website, social handles,
    do's and don'ts. usp_PartyBrand_Save is left as it is (the Web Forms app still calls it);
    the kit has its own procedures. Idempotent.  */

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* Named colours are stored as JSON: [{"name":"Primary","hex":"#E63946"},…]. 200 characters
   holds three; real brand books have six to ten. */
IF COL_LENGTH('dbo.tbl_PartyBrands', 'ColorPalette') < 2000
    ALTER TABLE dbo.tbl_PartyBrands ALTER COLUMN ColorPalette NVARCHAR(1000) NULL;

IF COL_LENGTH('dbo.tbl_PartyBrands', 'LogoDarkPath') IS NULL
    ALTER TABLE dbo.tbl_PartyBrands ADD
        LogoDarkPath  NVARCHAR(300)  NULL,
        FontHeading   NVARCHAR(80)   NULL,
        FontBody      NVARCHAR(80)   NULL,
        Tagline       NVARCHAR(200)  NULL,
        Website       NVARCHAR(200)  NULL,
        Instagram     NVARCHAR(100)  NULL,
        Facebook      NVARCHAR(100)  NULL,
        LinkedIn      NVARCHAR(100)  NULL,
        YouTube       NVARCHAR(100)  NULL,
        Guidelines    NVARCHAR(2000) NULL;
GO

CREATE OR ALTER PROCEDURE dbo.usp_PartyBrand_GetKit
    @TenantId     BIGINT,
    @PartyId      BIGINT,
    @PartyBrandId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ResultCode = 0, ResultMessage = N'Ok',
           b.PartyBrandId, b.PartyId, PartyName = p.DisplayName,
           b.BrandName, b.BrandCode, b.Description,
           b.LogoPath, b.LogoDarkPath, b.ColorPalette,
           b.FontHeading, b.FontBody, b.Tagline, b.Website,
           b.Instagram, b.Facebook, b.LinkedIn, b.YouTube, b.Guidelines,
           b.UpdatedAtUtc
      FROM dbo.tbl_PartyBrands b
     INNER JOIN dbo.tbl_Parties p ON p.PartyId = b.PartyId AND p.TenantId = b.TenantId
     WHERE b.TenantId = @TenantId AND b.PartyId = @PartyId AND b.PartyBrandId = @PartyBrandId AND b.IsActive = 1;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_PartyBrand_SaveKit
    @TenantId       BIGINT,
    @PartyId        BIGINT,
    @PartyBrandId   BIGINT,
    @ColorPalette   NVARCHAR(1000) = NULL,
    @FontHeading    NVARCHAR(80)   = NULL,
    @FontBody       NVARCHAR(80)   = NULL,
    @Tagline        NVARCHAR(200)  = NULL,
    @Website        NVARCHAR(200)  = NULL,
    @Instagram      NVARCHAR(100)  = NULL,
    @Facebook       NVARCHAR(100)  = NULL,
    @LinkedIn       NVARCHAR(100)  = NULL,
    @YouTube        NVARCHAR(100)  = NULL,
    @Guidelines     NVARCHAR(2000) = NULL,
    @ActionByUserId BIGINT,
    @IpAddress      VARCHAR(45)    = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @ColorPalette IS NOT NULL AND ISJSON(@ColorPalette) = 0
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'The colour list is not valid', FieldName = 'ColorPalette';
        RETURN;
    END

    UPDATE dbo.tbl_PartyBrands
       SET ColorPalette = @ColorPalette, FontHeading = @FontHeading, FontBody = @FontBody,
           Tagline = @Tagline, Website = @Website, Instagram = @Instagram, Facebook = @Facebook,
           LinkedIn = @LinkedIn, YouTube = @YouTube, Guidelines = @Guidelines,
           UpdatedAtUtc = SYSUTCDATETIME(), UpdatedBy = @ActionByUserId
     WHERE TenantId = @TenantId AND PartyId = @PartyId AND PartyBrandId = @PartyBrandId AND IsActive = 1;

    IF @@ROWCOUNT = 0
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'That brand no longer exists';
        RETURN;
    END

    INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, Summary, IpAddress)
    VALUES(@TenantId, @ActionByUserId, 'Party.BrandKitUpdated', 'PartyBrand', @PartyBrandId, N'Brand kit updated', @IpAddress);

    SELECT ResultCode = 0, ResultMessage = N'Ok';
END
GO

/* @Variant: 1 logo for light backgrounds, 2 for dark. @Path NULL removes it.
   Returns the path it replaced, so the caller can delete the old file. */
CREATE OR ALTER PROCEDURE dbo.usp_PartyBrand_SetLogo
    @TenantId       BIGINT,
    @PartyId        BIGINT,
    @PartyBrandId   BIGINT,
    @Variant        TINYINT,
    @Path           NVARCHAR(300) = NULL,
    @ActionByUserId BIGINT,
    @IpAddress      VARCHAR(45)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Variant NOT IN (1, 2)
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'Unknown logo variant';
        RETURN;
    END

    DECLARE @old NVARCHAR(300);
    SELECT @old = CASE @Variant WHEN 1 THEN LogoPath ELSE LogoDarkPath END
      FROM dbo.tbl_PartyBrands
     WHERE TenantId = @TenantId AND PartyId = @PartyId AND PartyBrandId = @PartyBrandId AND IsActive = 1;

    IF @@ROWCOUNT = 0
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'That brand no longer exists';
        RETURN;
    END

    UPDATE dbo.tbl_PartyBrands
       SET LogoPath     = CASE WHEN @Variant = 1 THEN @Path ELSE LogoPath END,
           LogoDarkPath = CASE WHEN @Variant = 2 THEN @Path ELSE LogoDarkPath END,
           UpdatedAtUtc = SYSUTCDATETIME(), UpdatedBy = @ActionByUserId
     WHERE TenantId = @TenantId AND PartyId = @PartyId AND PartyBrandId = @PartyBrandId;

    INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, Summary, IpAddress)
    VALUES(@TenantId, @ActionByUserId, CASE WHEN @Path IS NULL THEN 'Party.BrandLogoRemoved' ELSE 'Party.BrandLogoSet' END,
           'PartyBrand', @PartyBrandId, CASE @Variant WHEN 1 THEN N'Logo' ELSE N'Logo for dark backgrounds' END, @IpAddress);

    SELECT ResultCode = 0, ResultMessage = N'Ok', OldPath = @old;
END
GO
