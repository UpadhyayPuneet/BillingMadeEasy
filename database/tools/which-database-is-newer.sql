/*  Which database holds the newest work?
    Run in SSMS against the SQL Server instance (any database selected). Read-only.

    For every user database it reports:
      - which design it holds: the redesign (tbl_* tables, usp_* procedures) or the
        earlier one (Organizations, Users, sp_* procedures)
      - when it was created, and when its newest table and procedure were last changed

    The row with the latest LastChanged is where the most recent work went. If both
    designs are in one database, that shows up as non-zero counts in both columns.  */

SET NOCOUNT ON;

DECLARE @results TABLE
(
    DatabaseName      sysname,
    CreatedOn         datetime,
    RedesignTables    int,   -- tbl_*
    RedesignProcs     int,   -- usp_*
    EarlierTables     int,   -- Organizations, Users, Invoices…
    EarlierProcs      int,   -- sp_*
    NewestTable       sysname NULL,
    NewestTableAt     datetime NULL,
    NewestProc        sysname NULL,
    NewestProcAt      datetime NULL
);

DECLARE @name sysname, @sql nvarchar(max);

DECLARE dbs CURSOR LOCAL FAST_FORWARD FOR
    SELECT name FROM sys.databases
    WHERE database_id > 4 AND state_desc = 'ONLINE' AND HAS_DBACCESS(name) = 1;

OPEN dbs;
FETCH NEXT FROM dbs INTO @name;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'
        USE ' + QUOTENAME(@name) + N';
        SELECT
            DB_NAME(),
            (SELECT create_date FROM sys.databases WHERE name = DB_NAME()),
            (SELECT COUNT(*) FROM sys.tables WHERE name LIKE ''tbl[_]%''),
            (SELECT COUNT(*) FROM sys.procedures WHERE name LIKE ''usp[_]%''),
            (SELECT COUNT(*) FROM sys.tables WHERE name IN (''Organizations'', ''Users'', ''Invoices'', ''Items'', ''Customers'')),
            (SELECT COUNT(*) FROM sys.procedures WHERE name LIKE ''sp[_]%'' OR name LIKE ''sp[A-Z]%''),
            t.name, t.modify_date, p.name, p.modify_date
        FROM (SELECT 1 AS x) one
        OUTER APPLY (SELECT TOP 1 name, modify_date FROM sys.tables ORDER BY modify_date DESC) t
        OUTER APPLY (SELECT TOP 1 name, modify_date FROM sys.procedures ORDER BY modify_date DESC) p;';

    INSERT INTO @results EXEC sys.sp_executesql @sql;
    FETCH NEXT FROM dbs INTO @name;
END
CLOSE dbs;
DEALLOCATE dbs;

SELECT
    DatabaseName,
    CASE
        WHEN RedesignTables > 0 AND EarlierTables > 0 THEN 'Both designs'
        WHEN RedesignTables > 0 THEN 'Redesign (tbl_ / usp_)'
        WHEN EarlierTables > 0 THEN 'Earlier design (Organizations / sp_)'
        ELSE 'Neither'
    END AS Holds,
    RedesignTables, RedesignProcs, EarlierTables, EarlierProcs,
    CreatedOn,
    CASE WHEN NewestProcAt > NewestTableAt OR NewestTableAt IS NULL THEN NewestProcAt ELSE NewestTableAt END AS LastChanged,
    NewestTable, NewestTableAt, NewestProc, NewestProcAt
FROM @results
ORDER BY LastChanged DESC;
