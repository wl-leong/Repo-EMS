-- =============================================
-- Description:	Index defragmentation for the EMS database.
--				Reorganizes indexes at 5-30% fragmentation, rebuilds above 30%,
--				then updates statistics on the tables that were touched.
-- Usage:		Run in SSMS / Azure Data Studio / sqlcmd against the EMS database.
--				@Execute = 0 (default) only reports what would be done; set it to 1 to apply.
--				Run Execute=1 outside business hours: offline REBUILD locks the table.
-- =============================================
SET NOCOUNT ON;

DECLARE @Execute        BIT = 0;        -- 0 = report only, 1 = apply
DECLARE @MinPageCount   INT = 1000;     -- small indexes are not worth defragmenting
DECLARE @ReorgThreshold FLOAT = 5.0;
DECLARE @RebuildThreshold FLOAT = 30.0;
DECLARE @Online         BIT = CASE WHEN CAST(SERVERPROPERTY('EngineEdition') AS INT) IN (3, 5, 8) THEN 1 ELSE 0 END; -- Enterprise / Azure SQL DB / Managed Instance

IF OBJECT_ID('tempdb..#work') IS NOT NULL DROP TABLE #work;

SELECT
    s.name                          AS schemaName,
    o.name                          AS tableName,
    i.name                          AS indexName,
    ps.index_type_desc              AS indexType,
    ps.page_count                   AS pageCount,
    CAST(ps.avg_fragmentation_in_percent AS DECIMAL(5, 2)) AS fragPct,
    CASE
        WHEN ps.avg_fragmentation_in_percent >= @RebuildThreshold THEN 'REBUILD'
        ELSE 'REORGANIZE'
    END                             AS action
INTO #work
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') AS ps
    INNER JOIN sys.indexes AS i
        ON ps.object_id = i.object_id
        AND ps.index_id = i.index_id
    INNER JOIN sys.objects AS o
        ON i.object_id = o.object_id
    INNER JOIN sys.schemas AS s
        ON o.schema_id = s.schema_id
WHERE ps.index_id > 0                   -- skip heaps
    AND ps.alloc_unit_type_desc = 'IN_ROW_DATA'
    AND ps.page_count >= @MinPageCount
    AND ps.avg_fragmentation_in_percent >= @ReorgThreshold
    AND o.is_ms_shipped = 0;

-- Report
SELECT schemaName, tableName, indexName, indexType, pageCount, fragPct, action
FROM #work
ORDER BY fragPct DESC;

IF @Execute = 0
BEGIN
    PRINT 'Report only. Set @Execute = 1 and re-run to apply.';
    RETURN;
END

DECLARE @schema SYSNAME, @table SYSNAME, @index SYSNAME, @action VARCHAR(10), @sql NVARCHAR(MAX);

DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT schemaName, tableName, indexName, action FROM #work ORDER BY pageCount;

OPEN cur;
FETCH NEXT FROM cur INTO @schema, @table, @index, @action;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'ALTER INDEX ' + QUOTENAME(@index) + N' ON ' + QUOTENAME(@schema) + N'.' + QUOTENAME(@table)
        + CASE
            WHEN @action = 'REBUILD' THEN N' REBUILD WITH (SORT_IN_TEMPDB = ON' + CASE WHEN @Online = 1 THEN N', ONLINE = ON' ELSE N'' END + N')'
            ELSE N' REORGANIZE'
          END + N';';

    BEGIN TRY
        PRINT CONVERT(VARCHAR(19), GETDATE(), 120) + '  ' + @sql;
        EXEC sys.sp_executesql @sql;
    END TRY
    BEGIN CATCH
        PRINT '    FAILED: ' + ERROR_MESSAGE();
    END CATCH

    FETCH NEXT FROM cur INTO @schema, @table, @index, @action;
END

CLOSE cur;
DEALLOCATE cur;

-- REBUILD refreshes statistics itself; REORGANIZE does not
DECLARE stat CURSOR LOCAL FAST_FORWARD FOR
    SELECT DISTINCT schemaName, tableName FROM #work WHERE action = 'REORGANIZE';

OPEN stat;
FETCH NEXT FROM stat INTO @schema, @table;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'UPDATE STATISTICS ' + QUOTENAME(@schema) + N'.' + QUOTENAME(@table) + N';';
    PRINT CONVERT(VARCHAR(19), GETDATE(), 120) + '  ' + @sql;
    EXEC sys.sp_executesql @sql;
    FETCH NEXT FROM stat INTO @schema, @table;
END

CLOSE stat;
DEALLOCATE stat;

PRINT 'Done.';
