/*  31 · Lock a session on request.
    Used when the screen locks itself after inactivity and when someone chooses "Lock now",
    so the unlock screen is backed by the server rather than only by the page.
    Idempotent.  */

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Auth_Session_Lock
    @SessionKeyHash VARBINARY(32)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.tbl_UserSessions
       SET LockedAtUtc = ISNULL(LockedAtUtc, SYSUTCDATETIME())
     WHERE SessionKeyHash = @SessionKeyHash AND EndedAtUtc IS NULL;

    SELECT ResultCode = CASE WHEN @@ROWCOUNT = 0 THEN 1 ELSE 0 END, ResultMessage = N'Ok';
END
GO
