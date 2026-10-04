/*  32 · Who already has this GSTIN?
    Lets the new-party form warn before a duplicate is created, instead of finding out when
    the branch is refused. Uses UX_PartyLoc_Gstin. Idempotent.  */

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Party_FindByGstin
    @TenantId BIGINT,
    @Gstin    VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (1) p.PartyId, p.DisplayName, p.IsActive, l.PartyLocationId, l.LocationName
      FROM dbo.tbl_PartyLocations l
     INNER JOIN dbo.tbl_Parties p ON p.PartyId = l.PartyId AND p.TenantId = l.TenantId
     WHERE l.TenantId = @TenantId
       AND l.Gstin = UPPER(LTRIM(RTRIM(@Gstin)))
       AND l.IsActive = 1
     ORDER BY p.IsActive DESC;
END
GO
