USE SQLInventory;
GO

/*
  Collects SQL Agent job last-run status from remote msdb and upserts into
  inventory.SQLMaintenanceJobRun for today's SnapshotDate.
*/

CREATE OR ALTER PROCEDURE inventory.usp_Collect_SQLMaintenanceJobs
  @OnlyBUID INT = NULL,
  @OnlyServerID INT = NULL,
  @OnlySQLInstanceID INT = NULL
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @today DATE = CONVERT(date, SYSDATETIME());

  IF OBJECT_ID('tempdb..#Inst') IS NOT NULL DROP TABLE #Inst;
  CREATE TABLE #Inst
  (
    SQLInstanceID INT NOT NULL PRIMARY KEY,
    LinkedServerName SYSNAME NOT NULL
  );

  INSERT INTO #Inst (SQLInstanceID, LinkedServerName)
  SELECT
    si.SQLInstanceID,
    COALESCE(
      l.LinkedServerName,
      CASE WHEN UPPER(si.InstanceName) = 'MSSQLSERVER' THEN s.ServerName ELSE s.ServerName + '\\' + si.InstanceName END
    ) AS LinkedServerName
  FROM inventory.SQLInstance si
  INNER JOIN inventory.Server s ON s.ServerID = si.ServerID
  LEFT JOIN inventory.SQLInstanceLinkedServer l ON l.SQLInstanceID = si.SQLInstanceID AND l.IsActive = 1
  WHERE ISNULL(si.IsActive, 1) = 1
    AND (@OnlySQLInstanceID IS NULL OR si.SQLInstanceID = @OnlySQLInstanceID)
    AND (@OnlyServerID IS NULL OR s.ServerID = @OnlyServerID)
    AND (@OnlyBUID IS NULL OR s.BUID = @OnlyBUID);

  DECLARE @SQLInstanceID INT, @Linked SYSNAME, @dyn NVARCHAR(MAX);

  DECLARE inst_cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT SQLInstanceID, LinkedServerName FROM #Inst ORDER BY SQLInstanceID;

  OPEN inst_cur;
  FETCH NEXT FROM inst_cur INTO @SQLInstanceID, @Linked;

  WHILE @@FETCH_STATUS = 0
  BEGIN
    BEGIN TRY
      IF OBJECT_ID('tempdb..#J') IS NOT NULL DROP TABLE #J;
      CREATE TABLE #J
      (
        JobName VARCHAR(256) NOT NULL,
        LastRunDateTime DATETIME2 NULL,
        LastRunDurationSec INT NULL,
        LastRunStatus VARCHAR(30) NULL,
        LastRunMessage VARCHAR(4000) NULL
      );

      SET @dyn = N'
        SELECT
          j.name AS JobName,
          lh.LastRunDateTime,
          lh.LastRunDurationSec,
          lh.LastRunStatus,
          lh.LastRunMessage
        FROM ' + QUOTENAME(@Linked) + N'.msdb.dbo.sysjobs j
        OUTER APPLY (
          SELECT TOP (1)
            msdb.dbo.agent_datetime(h.run_date, h.run_time) AS LastRunDateTime,
            ( (h.run_duration / 10000) * 3600 ) + ( ((h.run_duration % 10000) / 100) * 60 ) + (h.run_duration % 100) AS LastRunDurationSec,
            CASE h.run_status
              WHEN 0 THEN ''Failed''
              WHEN 1 THEN ''Succeeded''
              WHEN 2 THEN ''Retry''
              WHEN 3 THEN ''Canceled''
              WHEN 4 THEN ''In Progress''
              ELSE ''Unknown''
            END AS LastRunStatus,
            LEFT(COALESCE(h.message, ''''), 4000) AS LastRunMessage
          FROM ' + QUOTENAME(@Linked) + N'.msdb.dbo.sysjobhistory h
          WHERE h.job_id = j.job_id AND h.step_id = 0
          ORDER BY h.instance_id DESC
        ) lh
        WHERE j.enabled = 1;
      ';

      INSERT INTO #J
      EXEC sys.sp_executesql @dyn;

      MERGE inventory.SQLMaintenanceJobRun AS tgt
      USING (
        SELECT
          @today AS SnapshotDate,
          @SQLInstanceID AS SQLInstanceID,
          JobName,
          LastRunDateTime,
          LastRunDurationSec,
          LastRunStatus,
          LastRunMessage
        FROM #J
      ) AS src
      ON tgt.SnapshotDate = src.SnapshotDate AND tgt.SQLInstanceID = src.SQLInstanceID AND tgt.JobName = src.JobName
      WHEN MATCHED THEN
        UPDATE SET
          tgt.LastRunDateTime = src.LastRunDateTime,
          tgt.LastRunDurationSec = src.LastRunDurationSec,
          tgt.LastRunStatus = src.LastRunStatus,
          tgt.LastRunMessage = src.LastRunMessage
      WHEN NOT MATCHED THEN
        INSERT (SnapshotDate, SQLInstanceID, JobName, LastRunDateTime, LastRunDurationSec, LastRunStatus, LastRunMessage)
        VALUES (src.SnapshotDate, src.SQLInstanceID, src.JobName, src.LastRunDateTime, src.LastRunDurationSec, src.LastRunStatus, src.LastRunMessage);

    END TRY
    BEGIN CATCH
      PRINT CONCAT('Job collect failed for SQLInstanceID=', @SQLInstanceID, ' LinkedServer=', @Linked, ' Error=', ERROR_MESSAGE());
    END CATCH;

    FETCH NEXT FROM inst_cur INTO @SQLInstanceID, @Linked;
  END

  CLOSE inst_cur;
  DEALLOCATE inst_cur;
END
GO

