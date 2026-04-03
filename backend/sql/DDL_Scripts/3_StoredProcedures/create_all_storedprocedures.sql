USE [SQLInventory]
GO
/****** Object:  StoredProcedure [inventory].[usp_Calc_SQLDatabaseMonthlyMax]    Script Date: 4/2/2026 4:33:42 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
  Calculates monthly max database size from inventory.SQLDatabaseDailySnapshot
  and upserts into inventory.SQLDatabaseMonthlyMax.

  Default: last 6 months including current month-to-date.
*/

CREATE   PROCEDURE [inventory].[usp_Calc_SQLDatabaseMonthlyMax]
  @MonthsBack INT = 6
AS
BEGIN
  SET NOCOUNT ON;

  IF @MonthsBack IS NULL OR @MonthsBack < 1 SET @MonthsBack = 6;

  DECLARE @start DATE = DATEFROMPARTS(YEAR(DATEADD(month, -(@MonthsBack - 1), CAST(SYSDATETIME() AS date))), MONTH(DATEADD(month, -(@MonthsBack - 1), CAST(SYSDATETIME() AS date))), 1);

  ;WITH agg AS (
    SELECT
      CONVERT(char(7), SnapshotDate, 126) AS YearMonth,
      SQLInstanceID,
      DatabaseName,
      MAX(DataSizeGB) AS MaxDataSizeGB,
      MAX(LogSizeGB) AS MaxLogSizeGB
    FROM inventory.SQLDatabaseDailySnapshot
    WHERE SnapshotDate >= @start
    GROUP BY CONVERT(char(7), SnapshotDate, 126), SQLInstanceID, DatabaseName
  )
  MERGE inventory.SQLDatabaseMonthlyMax AS tgt
  USING agg AS src
  ON tgt.YearMonth = src.YearMonth AND tgt.SQLInstanceID = src.SQLInstanceID AND tgt.DatabaseName = src.DatabaseName
  WHEN MATCHED THEN
    UPDATE SET
      tgt.MaxDataSizeGB = src.MaxDataSizeGB,
      tgt.MaxLogSizeGB = src.MaxLogSizeGB,
      tgt.CalcDate = SYSDATETIME()
  WHEN NOT MATCHED THEN
    INSERT (YearMonth, SQLInstanceID, DatabaseName, MaxDataSizeGB, MaxLogSizeGB)
    VALUES (src.YearMonth, src.SQLInstanceID, src.DatabaseName, src.MaxDataSizeGB, src.MaxLogSizeGB);
END

GO
/****** Object:  StoredProcedure [inventory].[usp_Collect_DatabaseBackups_Last24h]    Script Date: 4/2/2026 4:33:42 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
  Collects:
  - last 24 hours successful backups (D/I/L) and
  - latest available FULL backup per database (even if older than 24 hours)

  from a specific Linked Server name, and inserts into inventory.DatabaseBackup.

  This supports weekly FULL policies while still showing the latest FULL in reports.
*/

CREATE   PROCEDURE [inventory].[usp_Collect_DatabaseBackups_Last24h]
  @LinkedServerName SYSNAME
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @since DATETIME2 = DATEADD(hour, -24, SYSDATETIME());

  IF OBJECT_ID('tempdb..#Inst') IS NOT NULL DROP TABLE #Inst;
  CREATE TABLE #Inst
  (
    SQLInstanceID INT NOT NULL PRIMARY KEY,
    LinkedServerName SYSNAME NOT NULL
  );

  INSERT INTO #Inst (SQLInstanceID, LinkedServerName)
  SELECT
    si.SQLInstanceID,
    l.LinkedServerName
  FROM inventory.SQLInstance si
  INNER JOIN inventory.Server s ON s.ServerID = si.ServerID
  INNER JOIN inventory.SQLInstanceLinkedServer l ON l.SQLInstanceID = si.SQLInstanceID AND l.IsActive = 1
  WHERE ISNULL(si.IsActive, 1) = 1
    AND l.LinkedServerName = @LinkedServerName;

  DECLARE @SQLInstanceID INT, @Linked SYSNAME, @dyn NVARCHAR(MAX);

  DECLARE inst_cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT SQLInstanceID, LinkedServerName FROM #Inst ORDER BY SQLInstanceID;

  OPEN inst_cur;
  FETCH NEXT FROM inst_cur INTO @SQLInstanceID, @Linked;

  WHILE @@FETCH_STATUS = 0
  BEGIN
    BEGIN TRY
      IF OBJECT_ID('tempdb..#B') IS NOT NULL DROP TABLE #B;
      CREATE TABLE #B
      (
        DatabaseName VARCHAR(256) NOT NULL,
        BackupType CHAR(1) NOT NULL,
        BackupStartDate DATETIME2 NOT NULL,
        BackupFinishDate DATETIME2 NOT NULL,
        BackupSizeMB DECIMAL(18,2) NULL,
        IsCopyOnly BIT NOT NULL,
        BackupSetID INT NOT NULL
      );

      SET @dyn = N'
        WITH last24 AS (
          SELECT
            bs.database_name AS DatabaseName,
            bs.type AS BackupType,
            bs.backup_start_date AS BackupStartDate,
            bs.backup_finish_date AS BackupFinishDate,
            CAST(bs.backup_size / 1024.0 / 1024.0 AS decimal(18,2)) AS BackupSizeMB,
            CAST(ISNULL(bs.is_copy_only, 0) AS bit) AS IsCopyOnly,
            bs.backup_set_id AS BackupSetID
          FROM ' + QUOTENAME(@Linked) + N'.msdb.dbo.backupset bs
          WHERE bs.backup_finish_date >= @since
            AND bs.type IN (''D'',''I'',''L'')
            AND bs.is_copy_only = 0
            AND bs.user_name LIKE ''%NT AUTHORITY\SYSTEM%''
        ),
        latestFull AS (
          SELECT
            x.DatabaseName,
            x.BackupType,
            x.BackupStartDate,
            x.BackupFinishDate,
            x.BackupSizeMB,
            x.IsCopyOnly,
            x.BackupSetID
          FROM (
            SELECT
              bs.database_name AS DatabaseName,
              bs.type AS BackupType,
              bs.backup_start_date AS BackupStartDate,
              bs.backup_finish_date AS BackupFinishDate,
              CAST(bs.backup_size / 1024.0 / 1024.0 AS decimal(18,2)) AS BackupSizeMB,
              CAST(ISNULL(bs.is_copy_only, 0) AS bit) AS IsCopyOnly,
              bs.backup_set_id AS BackupSetID,
              ROW_NUMBER() OVER (PARTITION BY bs.database_name ORDER BY bs.backup_finish_date DESC) AS rn
            FROM ' + QUOTENAME(@Linked) + N'.msdb.dbo.backupset bs
            WHERE bs.type = ''D''
              AND bs.is_copy_only = 0
              AND bs.user_name LIKE ''%NT AUTHORITY\SYSTEM%''
          ) x
          WHERE x.rn = 1
        )
        SELECT * FROM last24
        UNION
        SELECT * FROM latestFull;
      ';

      INSERT INTO #B
      EXEC sys.sp_executesql @dyn, N'@since datetime2', @since=@since;

      INSERT INTO inventory.DatabaseBackup
      (SQLInstanceID, DatabaseName, BackupType, BackupStartDate, BackupFinishDate, BackupSizeMB, IsCopyOnly, BackupSetID)
      SELECT
        @SQLInstanceID,
        b.DatabaseName,
        b.BackupType,
        b.BackupStartDate,
        b.BackupFinishDate,
        b.BackupSizeMB,
        b.IsCopyOnly,
        b.BackupSetID
      FROM #B b
      WHERE NOT EXISTS (
        SELECT 1 FROM inventory.DatabaseBackup x
        WHERE x.SQLInstanceID = @SQLInstanceID AND x.BackupSetID = b.BackupSetID
      );

    END TRY
    BEGIN CATCH
      PRINT CONCAT('Backup collect failed for SQLInstanceID=', @SQLInstanceID, ' LinkedServer=', @Linked, ' Error=', ERROR_MESSAGE());
    END CATCH;

    FETCH NEXT FROM inst_cur INTO @SQLInstanceID, @Linked;
  END

  CLOSE inst_cur;
  DEALLOCATE inst_cur;
END

GO
/****** Object:  StoredProcedure [inventory].[usp_Collect_SQLMaintenanceJobs]    Script Date: 4/2/2026 4:33:42 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
  Collects SQL Agent job last-run status from remote msdb and upserts into
  inventory.SQLMaintenanceJobRun for today's SnapshotDate.
*/

CREATE   PROCEDURE [inventory].[usp_Collect_SQLMaintenanceJobs]
  @LinkedServerName SYSNAME 
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
    l.linkedServerName
  FROM inventory.SQLInstance si
  INNER JOIN inventory.Server s ON s.ServerID = si.ServerID
  INNER JOIN inventory.SQLInstanceLinkedServer l ON l.SQLInstanceID = si.SQLInstanceID AND l.IsActive = 1
  WHERE ISNULL(si.IsActive, 1) = 1 AND l.linkedServerName = @LinkedServerName AND l.IsActive = 1

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
        LastRunMessage VARCHAR(4000) NULL,
        JobCategory VARCHAR(128) NULL
      );

      SET @dyn = N'
        SELECT
          j.name AS JobName,
          lh.LastRunDateTime,
          lh.LastRunDurationSec,
          lh.LastRunStatus,
          lh.LastRunMessage,
          jc.name AS JobCategory
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
        INNER JOIN ' + QUOTENAME(@Linked) + N'.msdb.dbo.syscategories jc ON j.category_id = jc.category_id
        WHERE j.enabled = 1
        AND jc.name IN (''DBA Inventory'',''DBA Maintenance'', ''DBA Backup'', ''DBA Monitoring'', ''DBA Reports'', ''Database Maintenance'');
      ';

      INSERT INTO #J
      EXEC sys.sp_executesql @dyn;
      --SELECT * FROM #J
      MERGE inventory.SQLMaintenanceJobRun AS tgt
      USING (
        SELECT
          @today AS SnapshotDate,
          @SQLInstanceID AS SQLInstanceID,
          JobName,
          LastRunDateTime,
          LastRunDurationSec,
          LastRunStatus,
          LastRunMessage,
          JobCategory
        FROM #J
      ) AS src
      ON tgt.SnapshotDate = src.SnapshotDate AND tgt.SQLInstanceID = src.SQLInstanceID AND tgt.JobName = src.JobName
      WHEN MATCHED THEN
        UPDATE SET
          tgt.LastRunDateTime = src.LastRunDateTime,
          tgt.LastRunDurationSec = src.LastRunDurationSec,
          tgt.LastRunStatus = src.LastRunStatus,
          tgt.LastRunMessage = src.LastRunMessage,
          tgt.JobCategory = src.JobCategory
      WHEN NOT MATCHED THEN
        INSERT (SnapshotDate, SQLInstanceID, JobName, LastRunDateTime, LastRunDurationSec, LastRunStatus, LastRunMessage,JobCategory)
        VALUES (src.SnapshotDate, src.SQLInstanceID, src.JobName, src.LastRunDateTime, src.LastRunDurationSec, src.LastRunStatus, src.LastRunMessage,src.JobCategory);

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
/****** Object:  StoredProcedure [inventory].[usp_Email_HealthReport_Prod]    Script Date: 4/2/2026 4:33:42 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE   PROCEDURE [inventory].[usp_Email_HealthReport_Prod]
  @ProfileName SYSNAME,
  @Recipients NVARCHAR(MAX),
  @OnlyBUID INT = NULL
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @sid INT;
  DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT s.ServerID
    FROM inventory.Server s
    INNER JOIN inventory.Environment env ON env.EnvID = s.EnvID
    INNER JOIN inventory.ServerStatus ss ON ss.StatusID = s.StatusID
    WHERE env.EnvName = 'PROD'
      AND ss.StatusName = 'IN USE'
      AND (@OnlyBUID IS NULL OR s.BUID = @OnlyBUID)
    ORDER BY s.ServerName;

  OPEN cur;
  FETCH NEXT FROM cur INTO @sid;
  WHILE @@FETCH_STATUS = 0
  BEGIN
    BEGIN TRY
      EXEC inventory.usp_Email_HealthReport_Server
        @ProfileName=@ProfileName,
        @Recipients=@Recipients,
        @ServerID=@sid,
        @SubjectPrefix=N'SQL Health Report';
    END TRY
    BEGIN CATCH
      PRINT CONCAT('Email failed for ServerID=', @sid, ' Error=', ERROR_MESSAGE());
    END CATCH;

    FETCH NEXT FROM cur INTO @sid;
  END

  CLOSE cur;
  DEALLOCATE cur;
END

GO
/****** Object:  StoredProcedure [inventory].[usp_Email_HealthReport_Server]    Script Date: 4/2/2026 4:33:42 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
  Sends Server Health Report via SQL Server Database Mail (sp_send_dbmail).

  Prereqs:
  - Database Mail configured and enabled on this SQL Server
  - @ProfileName exists
  - Collection tables are populated (DatabaseBackup, ServerStorage, SQLMaintenanceJobRun, SQLDatabase)

  Default behavior:
  - Sends one email per PROD + IN USE server (per-server emails are easier to read).
*/

CREATE   PROCEDURE [inventory].[usp_Email_HealthReport_Server]
  @ProfileName SYSNAME = 'SQLMailProfile',
  @Recipients NVARCHAR(MAX),
  @ccRecipients NVARCHAR(MAX) = NULL,
  @ServerID INT,
  @SubjectPrefix NVARCHAR(200) = N'SQL Health Report'
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @since DATETIME2 = DATEADD(hour, -24, SYSDATETIME());

  DECLARE @ServerName NVARCHAR(200), @BU NVARCHAR(200), @Env NVARCHAR(50), @Desc NVARCHAR(500);
  SELECT
    @ServerName = s.ServerName,
    @BU = bu.BusinessUnitName,
    @Env = env.EnvName,
    @Desc = s.Description
  FROM inventory.Server s
  INNER JOIN inventory.BusinessUnit bu ON bu.BUID = s.BUID
  INNER JOIN inventory.Environment env ON env.EnvID = s.EnvID
  WHERE s.ServerID = @ServerID;

  IF @ServerName IS NULL
    RETURN;

  DECLARE @inst TABLE (SQLInstanceID INT PRIMARY KEY, InstanceName NVARCHAR(200));
  INSERT INTO @inst (SQLInstanceID, InstanceName)
  SELECT SQLInstanceID, InstanceName
  FROM inventory.SQLInstance
  WHERE ServerID = @ServerID AND ISNULL(IsActive, 1) = 1;

  DECLARE @html NVARCHAR(MAX) = N'';
  SET @html += N'<h2 style="margin-bottom:4px;">' + ISNULL(@ServerName, N'') + N'</h2>';
  SET @html += N'<div style="color:#445; margin-bottom:8px;">' + ISNULL(@BU, N'') + N' | ' + ISNULL(@Env, N'') + N'</div>';
  IF NULLIF(@Desc, N'') IS NOT NULL
    SET @html += N'<div style="color:#667; margin-bottom:14px;">' + @Desc + N'</div>';

  -- Backup Summary (last 24 hours)
  SET @html += N'<h3>Database Backup Details</h3>';
  SET @html += N'<div style="color:#667; margin-top:-8px; margin-bottom:10px;">Druva Backup summary report from last 24 hours</div>';
  SET @html += N'<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; font-family:Segoe UI, Arial; font-size:12px;">';
  SET @html += N'<tr style="background:#f3f6fb;"><th align="left">Backup Type</th><th align="right">Successful</th><th align="right">Failed</th></tr>';

  ;WITH s AS (
    SELECT BackupType, COUNT(1) AS Successful
    FROM inventory.DatabaseBackup b
    WHERE b.BackupFinishDate >= @since
      AND EXISTS (SELECT 1 FROM @inst i WHERE i.SQLInstanceID = b.SQLInstanceID)
    GROUP BY BackupType
  )
  SELECT @html += (
    SELECT
      N'<tr><td>' +
      CASE t.BackupType WHEN 'L' THEN 'Transaction Logs' WHEN 'I' THEN 'Differential' WHEN 'D' THEN 'Full' ELSE t.BackupType END +
      N'</td><td align="right" style="background:#e9f8ef; font-weight:700;">' + CAST(ISNULL(s.Successful,0) AS NVARCHAR(20)) +
      N'</td><td align="right" style="background:#eef2f6; font-weight:700;">0</td></tr>'
    FROM (VALUES ('L'),('I'),('D')) t(BackupType)
    LEFT JOIN s ON s.BackupType = t.BackupType
    FOR XML PATH(''), TYPE
  ).value('.','nvarchar(max)');

  SET @html += N'</table>';

  -- Recent backups by database (latest full/diff)
  SET @html += N'<h3 style="margin-top:18px;">Database Backup Details</h3>';
  SET @html += N'<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; font-family:Segoe UI, Arial; font-size:12px;">';
  SET @html += N'<tr style="background:#f3f6fb;"><th align="left">SQL Instance</th><th align="left">Database</th><th align="left">Recent Full Backup</th><th align="left">Recent Diff Backup</th></tr>';

  ;WITH dbs AS (
    SELECT d.SQLInstanceID, d.DatabaseName
    FROM inventory.SQLDatabase d
    WHERE d.IsActive = 1
      AND EXISTS (SELECT 1 FROM @inst i WHERE i.SQLInstanceID = d.SQLInstanceID)
  ),
  fulls AS (
    SELECT SQLInstanceID, DatabaseName, MAX(BackupFinishDate) AS RecentFullBackupDate
    FROM inventory.DatabaseBackup
    WHERE BackupType = 'D'
      AND EXISTS (SELECT 1 FROM @inst i WHERE i.SQLInstanceID = SQLInstanceID)
    GROUP BY SQLInstanceID, DatabaseName
  ),
  diffs AS (
    SELECT SQLInstanceID, DatabaseName, MAX(BackupFinishDate) AS RecentDiffBackupDate
    FROM inventory.DatabaseBackup
    WHERE BackupType = 'I'
      AND EXISTS (SELECT 1 FROM @inst i WHERE i.SQLInstanceID = SQLInstanceID)
    GROUP BY SQLInstanceID, DatabaseName
  )
  SELECT @html += (
    SELECT
      N'<tr><td>' + i.InstanceName +
      N'</td><td>' + dbs.DatabaseName +
      N'</td><td>' + ISNULL(CONVERT(nvarchar(19), f.RecentFullBackupDate, 120), N'') +
      N'</td><td>' + ISNULL(CONVERT(nvarchar(19), d.RecentDiffBackupDate, 120), N'') +
      N'</td></tr>'
    FROM dbs
    INNER JOIN @inst i ON i.SQLInstanceID = dbs.SQLInstanceID
    LEFT JOIN fulls f ON f.SQLInstanceID = dbs.SQLInstanceID AND f.DatabaseName = dbs.DatabaseName
    LEFT JOIN diffs d ON d.SQLInstanceID = dbs.SQLInstanceID AND d.DatabaseName = dbs.DatabaseName
    ORDER BY i.InstanceName, dbs.DatabaseName
    FOR XML PATH(''), TYPE
  ).value('.','nvarchar(max)');

  SET @html += N'</table>';

  -- Disk space (SQL drives only)
  SET @html += N'<h3 style="margin-top:18px;">Disk Space Details</h3>';
  SET @html += N'<div style="color:#667; margin-top:-8px; margin-bottom:10px;">Disk space details for disk containing SQL files only. For OS and Backup disks or any additional storage history detail refer site 24x7.</div>';
  SET @html += N'<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; font-family:Segoe UI, Arial; font-size:12px;">';
  SET @html += N'<tr style="background:#f3f6fb;"><th align="left">Drive</th><th align="left">Volume</th><th align="right">Total GB</th><th align="right">Free GB</th><th align="right">Free %</th></tr>';

  SELECT @html += (
    SELECT
      N'<tr><td>' + s.DriveLetter +
      N'</td><td>' + ISNULL(s.VolumeLabel, N'') +
      N'</td><td align="right">' + CONVERT(nvarchar(32), s.TotalSizeGB) +
      N'</td><td align="right">' + CONVERT(nvarchar(32), s.FreeSpaceGB) +
      N'</td><td align="right">' +
      ISNULL(CONVERT(nvarchar(32), CASE WHEN s.TotalSizeGB > 0 THEN CAST((s.FreeSpaceGB*100.0)/s.TotalSizeGB AS decimal(5,2)) END), N'') +
      N'</td></tr>'
    FROM inventory.ServerStorage s
    WHERE s.ServerID = @ServerID AND s.IsActive = 1
    ORDER BY s.DriveLetter
    FOR XML PATH(''), TYPE
  ).value('.','nvarchar(max)');

  SET @html += N'</table>';

  -- Maintenance jobs (latest snapshot)
  DECLARE @snap DATE;
  SELECT @snap = MAX(SnapshotDate)
  FROM inventory.SQLMaintenanceJobRun
  WHERE EXISTS (SELECT 1 FROM @inst i WHERE i.SQLInstanceID = SQLInstanceID);

  SET @html += N'<h3 style="margin-top:18px;">Maintenance Job Details</h3>';
  SET @html += N'<div style="color:#667; margin-top:-8px; margin-bottom:10px;">Latest status of DBA jobs such as Maintenance/Backups/Monitoring, etc.</div>';
  SET @html += N'<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; font-family:Segoe UI, Arial; font-size:12px;">';
  SET @html += N'<tr style="background:#f3f6fb;"><th align="left">SQL Instance</th><th align="left">Job</th><th align="left">Last Run</th><th align="right">Duration (sec)</th><th align="left">Status</th></tr>';

  IF @snap IS NOT NULL
  BEGIN
    SELECT @html += (
      SELECT
        N'<tr><td>' + i.InstanceName +
        N'</td><td>' + j.JobName +
        N'</td><td>' + ISNULL(CONVERT(nvarchar(19), j.LastRunDateTime, 120), N'') +
        N'</td><td align="right">' + ISNULL(CONVERT(nvarchar(20), j.LastRunDurationSec), N'') +
        N'</td><td>' + ISNULL(j.LastRunStatus, N'') +
        N'</td></tr>'
      FROM inventory.SQLMaintenanceJobRun j
      INNER JOIN @inst i ON i.SQLInstanceID = j.SQLInstanceID
      WHERE j.SnapshotDate = @snap 
      AND j.lastRunDateTime IS NOT NULL
      ORDER BY i.InstanceName, j.JobName
      FOR XML PATH(''), TYPE
    ).value('.','nvarchar(max)');
  END

  SET @html += N'</table>';

  DECLARE @emailsub NVARCHAR(500) = @SubjectPrefix + N' - ' +@ServerName;

  EXEC msdb.dbo.sp_send_dbmail
    @profile_name = @ProfileName,
    @recipients = @Recipients,
    @copy_recipients = @ccRecipients,
    @subject = @emailSub,
    @body = @html,
    @body_format = 'HTML';
END


GO
/****** Object:  StoredProcedure [inventory].[usp_Refresh_ServerStorage_FromLinkedServers]    Script Date: 4/2/2026 4:33:42 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
  Refreshes inventory.ServerStorage from remote servers via a given Linked Server name.
  SQL-drives only: uses sys.dm_os_volume_stats driven by master.sys.master_files.
  (This will NOT include C: unless SQL has files on C:)

  Behavior per Server:
  - Deactivate existing active storage rows (IsActive=0)
  - Upsert freshly fetched rows (IsActive=1)

  Instance selection per Server:
  - Prefer MSSQLSERVER if present and active
  - Else first active instance for that server

  Requirements (Linked Server):
  - RPC OUT = TRUE (for EXEC ... AT)
*/

CREATE   PROCEDURE [inventory].[usp_Refresh_ServerStorage_FromLinkedServers]
  @LinkedServerName SYSNAME
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @ServerID INT, @SQLInstanceID INT, @Linked SYSNAME, @dyn NVARCHAR(MAX);

  IF OBJECT_ID('tempdb..#Srv') IS NOT NULL DROP TABLE #Srv;
  CREATE TABLE #Srv
  (
    ServerID INT NOT NULL PRIMARY KEY,
    SQLInstanceID INT NOT NULL,
    LinkedServerName SYSNAME NOT NULL
  );

  ;WITH inst AS (
    SELECT
      s.ServerID,
      si.SQLInstanceID,
      si.InstanceName,
      l.LinkedServerName,
      ROW_NUMBER() OVER (
        PARTITION BY s.ServerID
        ORDER BY CASE WHEN UPPER(si.InstanceName) = 'MSSQLSERVER' THEN 0 ELSE 1 END, si.SQLInstanceID
      ) AS rn
    FROM inventory.Server s
    INNER JOIN inventory.SQLInstance si
      ON si.ServerID = s.ServerID
     AND ISNULL(si.IsActive, 1) = 1
    INNER JOIN inventory.SQLInstanceLinkedServer l
      ON l.SQLInstanceID = si.SQLInstanceID
     AND l.IsActive = 1
    WHERE l.LinkedServerName = @LinkedServerName
  )
  INSERT INTO #Srv (ServerID, SQLInstanceID, LinkedServerName)
  SELECT ServerID, SQLInstanceID, LinkedServerName
  FROM inst
  WHERE rn = 1;

  DECLARE srv_cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT ServerID, SQLInstanceID, LinkedServerName FROM #Srv ORDER BY ServerID;

  OPEN srv_cur;
  FETCH NEXT FROM srv_cur INTO @ServerID, @SQLInstanceID, @Linked;

  WHILE @@FETCH_STATUS = 0
  BEGIN
    BEGIN TRY
      IF OBJECT_ID('tempdb..#Vol') IS NOT NULL DROP TABLE #Vol;
      CREATE TABLE #Vol
      (
        DriveLetter CHAR(1) NOT NULL,
        VolumeLabel NVARCHAR(260) NULL,
        TotalSizeGB DECIMAL(18,2) NOT NULL,
        FreeSpaceGB DECIMAL(18,2) NOT NULL
      );

      -- Run dm_os_volume_stats on the REMOTE server and insert results locally
      DECLARE @remoteVol NVARCHAR(MAX) = N'
        SET NOCOUNT ON;
        SELECT DISTINCT
          LEFT(vs.volume_mount_point, 1) AS DriveLetter,
          vs.logical_volume_name AS VolumeLabel,
          CAST(vs.total_bytes / 1024.0 / 1024.0 / 1024.0 AS decimal(18,2)) AS TotalSizeGB,
          CAST(vs.available_bytes / 1024.0 / 1024.0 / 1024.0 AS decimal(18,2)) AS FreeSpaceGB
        FROM master.sys.master_files mf
        CROSS APPLY master.sys.dm_os_volume_stats(mf.database_id, mf.file_id) vs
        WHERE vs.volume_mount_point LIKE ''[A-Z]:\%'';';

      SET @dyn = N'
        INSERT INTO #Vol (DriveLetter, VolumeLabel, TotalSizeGB, FreeSpaceGB)
        EXEC (N''' + REPLACE(@remoteVol, '''', '''''') + N''') AT ' + QUOTENAME(@Linked) + N';
      ';

      EXEC sys.sp_executesql @dyn;

      -- Exclude C drive explicitly
      --DELETE FROM #Vol WHERE DriveLetter = 'C';

      -- Deactivate previous active rows for the server
      UPDATE inventory.ServerStorage
      SET IsActive = 0
      WHERE ServerID = @ServerID AND IsActive = 1 AND DriveLetter <> 'C'

      -- Upsert per drive
      MERGE inventory.ServerStorage AS tgt
      USING (
        SELECT
          @ServerID AS ServerID,
          DriveLetter,
          LEFT(ISNULL(VolumeLabel, ''), 100) AS VolumeLabel,
          TotalSizeGB,
          FreeSpaceGB
        FROM #Vol
      ) AS src
      ON tgt.ServerID = src.ServerID AND tgt.DriveLetter = src.DriveLetter
      WHEN MATCHED THEN
        UPDATE SET
          tgt.VolumeLabel = COALESCE(NULLIF(src.VolumeLabel, ''), tgt.VolumeLabel),
          tgt.TotalSizeGB = src.TotalSizeGB,
          tgt.FreeSpaceGB = src.FreeSpaceGB,
          tgt.IsActive = 1,
          tgt.CreatedDate = GETDATE()
      WHEN NOT MATCHED THEN
        INSERT (ServerID, DriveLetter, VolumeLabel, TotalSizeGB, FreeSpaceGB, IsActive,CreatedDate)
        VALUES (src.ServerID, src.DriveLetter, src.VolumeLabel, src.TotalSizeGB, src.FreeSpaceGB, 1, GETDATE());

    END TRY
    BEGIN CATCH
      PRINT CONCAT('Storage refresh failed for ServerID=', @ServerID, ' LinkedServer=', @Linked, ' Error=', ERROR_MESSAGE());
    END CATCH;

    FETCH NEXT FROM srv_cur INTO @ServerID, @SQLInstanceID, @Linked;
  END

  CLOSE srv_cur;
  DEALLOCATE srv_cur;
END

GO
/****** Object:  StoredProcedure [inventory].[usp_Refresh_SQLDatabase_FromLinkedServers]    Script Date: 4/2/2026 4:33:42 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
  Refreshes inventory.SQLDatabase from remote servers via Linked Server connectivity.

  Behavior per SQLInstance:
  - Deactivate existing active rows (IsActive=0)
  - Upsert freshly fetched rows (IsActive=1)
  - Capture daily size snapshot into inventory.SQLDatabaseDailySnapshot

  Linked Server name resolution:
  1) inventory.SQLInstanceLinkedServer (if populated and IsActive=1)
  2) Default instance: ServerName
  3) Named instance:   ServerName\\InstanceName

  Requirements:
  - Linked Servers must be created on this central 
  host with RPC/queries enabled.
*/

CREATE   PROCEDURE [inventory].[usp_Refresh_SQLDatabase_FromLinkedServers]
  @LinkedServerName SYSNAME 
--  @OnlyBUID INT = NULL,
--  @OnlyServerID INT = NULL,
--  @OnlySQLInstanceID INT = NULL
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @today DATE = CONVERT(date, SYSDATETIME());

  IF OBJECT_ID('tempdb..#Inst') IS NOT NULL DROP TABLE #Inst;
  CREATE TABLE #Inst
  (
    SQLInstanceID INT NOT NULL PRIMARY KEY,
    ServerID INT NOT NULL,
    ServerName VARCHAR(150) NOT NULL,
    InstanceName VARCHAR(150) NOT NULL,
    LinkedServerName SYSNAME NOT NULL
  );

  INSERT INTO #Inst (SQLInstanceID, ServerID, ServerName, InstanceName, LinkedServerName)
  SELECT
    si.SQLInstanceID,
    s.ServerID,
    s.ServerName,
    si.InstanceName,
    l.LinkedServerName
  FROM inventory.SQLInstance si
  INNER JOIN inventory.Server s ON s.ServerID = si.ServerID
  INNER JOIN inventory.SQLInstanceLinkedServer l ON l.SQLInstanceID = si.SQLInstanceID AND l.IsActive = 1
  WHERE ISNULL(si.IsActive, 1) = 1 AND l.LinkedServerName = @LinkedServerName
  --  COALESCE(
  --    l.LinkedServerName,
  --    CASE
  --      WHEN UPPER(si.InstanceName) = 'MSSQLSERVER' THEN s.ServerName
  --      ELSE s.ServerName + '\\' + si.InstanceName
  --    END
  --  ) AS LinkedServerName
  --FROM inventory.SQLInstance si
  --INNER JOIN inventory.Server s ON s.ServerID = si.ServerID
  --LEFT JOIN inventory.SQLInstanceLinkedServer l ON l.SQLInstanceID = si.SQLInstanceID AND l.IsActive = 1
  --WHERE ISNULL(si.IsActive, 1) = 1
  --  AND (@OnlySQLInstanceID IS NULL OR si.SQLInstanceID = @OnlySQLInstanceID)
  --  AND (@OnlyServerID IS NULL OR s.ServerID = @OnlyServerID)
  --  AND (@OnlyBUID IS NULL OR s.BUID = @OnlyBUID);

  DECLARE
    @SQLInstanceID INT,
    @Linked SYSNAME,
    @dyn NVARCHAR(MAX);

  DECLARE inst_cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT SQLInstanceID, LinkedServerName FROM #Inst ORDER BY SQLInstanceID;

  OPEN inst_cur;
  FETCH NEXT FROM inst_cur INTO @SQLInstanceID, @Linked;

  WHILE @@FETCH_STATUS = 0
  BEGIN
    BEGIN TRY
      IF OBJECT_ID('tempdb..#DB') IS NOT NULL DROP TABLE #DB;
      CREATE TABLE #DB
      (
        DatabaseName VARCHAR(256) NOT NULL,
        Owner VARCHAR(128) NULL,
        SizeGB DECIMAL(18,2) NULL,
        DataSizeGB DECIMAL(18,2) NULL,
        LogSizeGB DECIMAL(18,2) NULL,
        CreatedOn DATETIME2 NULL,
        RecoveryModel VARCHAR(30) NULL,
        DatabaseCollation VARCHAR(128) NULL,
        CDC BIT NOT NULL,
        CompatibilityLevel INT NULL,
        Encryption BIT NOT NULL,
        QueryStore BIT NOT NULL,
        AutoUpdateStats BIT NOT NULL
      );

      SET @dyn = N'
        SELECT
          d.name AS DatabaseName,
          SUSER_SNAME(d.owner_sid) AS Owner,
          CAST((SUM(mf.size) * 8.0) / 1024.0 / 1024.0 AS decimal(18,2)) AS SizeGB,
          CAST((SUM(CASE WHEN mf.type_desc = ''ROWS'' THEN mf.size ELSE 0 END) * 8.0) / 1024.0 / 1024.0 AS decimal(18,2)) AS DataSizeGB,
          CAST((SUM(CASE WHEN mf.type_desc = ''LOG''  THEN mf.size ELSE 0 END) * 8.0) / 1024.0 / 1024.0 AS decimal(18,2)) AS LogSizeGB,
          d.create_date AS CreatedOn,
          d.recovery_model_desc AS RecoveryModel,
          d.collation_name AS DatabaseCollation,
          CAST(ISNULL(d.is_cdc_enabled, 0) AS bit) AS CDC,
          d.compatibility_level AS CompatibilityLevel,
          CAST(CASE WHEN EXISTS (
            SELECT 1 FROM ' + QUOTENAME(@Linked) + N'.master.sys.dm_database_encryption_keys dek
            WHERE dek.database_id = d.database_id AND dek.encryption_state = 3
          ) THEN 1 ELSE 0 END AS bit) AS Encryption,
          CAST(ISNULL(d.is_query_store_on, 0) AS bit) AS QueryStore,
          CAST(ISNULL(d.is_auto_update_stats_on, 0) AS bit) AS AutoUpdateStats
        FROM ' + QUOTENAME(@Linked) + N'.master.sys.databases d
        INNER JOIN ' + QUOTENAME(@Linked) + N'.master.sys.master_files mf ON mf.database_id = d.database_id
        WHERE d.database_id > 4
        GROUP BY
          d.database_id, d.name, d.owner_sid, d.create_date, d.recovery_model_desc, d.collation_name,
          d.is_cdc_enabled, d.compatibility_level, d.is_query_store_on, d.is_auto_update_stats_on;
      ';
      
      INSERT INTO #DB
     
      EXEC sys.sp_executesql @dyn;

      --SELECT * FROM #DB; -- For debugging/validation

      -- Deactivate previous active rows
      UPDATE inventory.SQLDatabase
      SET IsActive = 0, ModifiedDate = SYSDATETIME(), ModifiedBy = 'SP:usp_Refresh_SQLDatabase_FromLinkedServers'
      WHERE SQLInstanceID = @SQLInstanceID AND IsActive = 1;

      -- Upsert fetched rows (reactivate + update fields)
      MERGE inventory.SQLDatabase AS tgt
      USING (
        SELECT
          @SQLInstanceID AS SQLInstanceID,
          DatabaseName,
          Owner,
          SizeGB,
          DataSizeGB,
          LogSizeGB,
          CreatedOn,
          RecoveryModel,
          DatabaseCollation,
          CDC,
          CompatibilityLevel,
          Encryption,
          QueryStore,
          AutoUpdateStats
        FROM #DB
      ) AS src
      ON tgt.SQLInstanceID = src.SQLInstanceID AND tgt.DatabaseName = src.DatabaseName
      WHEN MATCHED THEN
        UPDATE SET
          tgt.Owner = src.Owner,
          tgt.SizeGB = src.SizeGB,
          tgt.DataSizeGB = src.DataSizeGB,
          tgt.LogSizeGB = src.LogSizeGB,
          tgt.CreatedOn = src.CreatedOn,
          tgt.RecoveryModel = src.RecoveryModel,
          tgt.DatabaseCollation = src.DatabaseCollation,
          tgt.CDC = src.CDC,
          tgt.CompatibilityLevel = src.CompatibilityLevel,
          tgt.Encryption = src.Encryption,
          tgt.QueryStore = src.QueryStore,
          tgt.AutoUpdateStats = src.AutoUpdateStats,
          tgt.IsActive = 1,
          tgt.ModifiedDate = SYSDATETIME(),
          tgt.ModifiedBy = 'SP:usp_Refresh_SQLDatabase_FromLinkedServers'
      WHEN NOT MATCHED THEN
        INSERT
        (SQLInstanceID, DatabaseName, Owner, SizeGB, DataSizeGB, LogSizeGB, CreatedOn, RecoveryModel, DatabaseCollation, CDC, CompatibilityLevel, Encryption, QueryStore, AutoUpdateStats, IsActive, CreatedBy)
        VALUES
        (src.SQLInstanceID, src.DatabaseName, src.Owner, src.SizeGB, src.DataSizeGB, src.LogSizeGB, src.CreatedOn, src.RecoveryModel, src.DatabaseCollation, src.CDC, src.CompatibilityLevel, src.Encryption, src.QueryStore, src.AutoUpdateStats, 1, 'SP:usp_Refresh_SQLDatabase_FromLinkedServers');

      -- Daily snapshot (upsert)
      MERGE inventory.SQLDatabaseDailySnapshot AS s
      USING (
        SELECT
          @today AS SnapshotDate,
          @SQLInstanceID AS SQLInstanceID,
          DatabaseName,
          DataSizeGB,
          LogSizeGB
        FROM #DB
      ) AS src
      ON s.SnapshotDate = src.SnapshotDate AND s.SQLInstanceID = src.SQLInstanceID AND s.DatabaseName = src.DatabaseName
      WHEN MATCHED THEN
        UPDATE SET s.DataSizeGB = src.DataSizeGB, s.LogSizeGB = src.LogSizeGB
      WHEN NOT MATCHED THEN
        INSERT (SnapshotDate, SQLInstanceID, DatabaseName, DataSizeGB, LogSizeGB)
        VALUES (src.SnapshotDate, src.SQLInstanceID, src.DatabaseName, src.DataSizeGB, src.LogSizeGB);

    END TRY
    BEGIN CATCH
      -- Fail one instance without killing the full run.
      PRINT CONCAT('Refresh failed for SQLInstanceID=', @SQLInstanceID, ' LinkedServer=', @Linked, ' Error=', ERROR_MESSAGE());
    END CATCH;

    FETCH NEXT FROM inst_cur INTO @SQLInstanceID, @Linked;
  END

  CLOSE inst_cur;
  DEALLOCATE inst_cur;
END

GO
/****** Object:  StoredProcedure [inventory].[usp_Sync_Database_PrimarySecondaryInstance]    Script Date: 4/2/2026 4:33:42 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE   PROCEDURE [inventory].[usp_Sync_Database_PrimarySecondaryInstance]
  @PrimarySQLInstanceID INT,
  @SecondarySQLInstanceID INT

AS
BEGIN  
    SET NOCOUNT ON;
    MERGE inventory.SQLDatabase AS tgt
          USING (
            SELECT
              DatabaseName,
              Owner,
              SizeGB,
              DataSizeGB,
              LogSizeGB,
              CreatedOn,
              RecoveryModel,
              DatabaseCollation,
              CDC,
              CompatibilityLevel,
              Encryption,
              QueryStore,
              AutoUpdateStats
            FROM inventory.SQLDatabase
            WHERE SQLInstanceID = @PrimarySQLInstanceID AND IsActive = 1
          ) AS src
          ON tgt.DatabaseName = src.DatabaseName AND tgt.SQLInstanceID = @SecondarySQLInstanceID
          WHEN MATCHED THEN
            UPDATE SET
              tgt.Owner = src.Owner,
              tgt.SizeGB = src.SizeGB,
              tgt.DataSizeGB = src.DataSizeGB,
              tgt.LogSizeGB = src.LogSizeGB,
              tgt.CreatedOn = src.CreatedOn,
              tgt.RecoveryModel = src.RecoveryModel,
              tgt.DatabaseCollation = src.DatabaseCollation,
              tgt.CDC = src.CDC,
              tgt.CompatibilityLevel = src.CompatibilityLevel,
              tgt.Encryption = src.Encryption,
              tgt.QueryStore = src.QueryStore,
              tgt.AutoUpdateStats = src.AutoUpdateStats,
              tgt.IsActive = 1,
              tgt.ModifiedDate = SYSDATETIME(),
              tgt.ModifiedBy = 'SP:usp_Sync_Database_PrimarySecondaryInstance'
           WHEN NOT MATCHED THEN
            INSERT
            (SQLInstanceID, DatabaseName, Owner, SizeGB, DataSizeGB, LogSizeGB, CreatedOn, RecoveryModel, DatabaseCollation, CDC, CompatibilityLevel, Encryption, QueryStore, AutoUpdateStats, IsActive, CreatedBy)
            VALUES
            (@SecondarySQLInstanceID, src.DatabaseName, src.Owner, src.SizeGB, src.DataSizeGB, src.LogSizeGB, src.CreatedOn, src.RecoveryModel, src.DatabaseCollation, src.CDC, src.CompatibilityLevel, src.Encryption, src.QueryStore, src.AutoUpdateStats, 1, 'SP:usp_Sync_Database_PrimarySecondaryInstance');
END
GO

/****** Object:  StoredProcedure [inventory].[usp_Email_DBTrend_Server]   Script Date: 4/2/2026 4:33:42 PM ******/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
  Sends Database Trend report via SQL Server Database Mail (sp_send_dbmail).

  This is a reference implementation to match the backend endpoint:
    POST /api/db-trend/email-report

  Expected parameters from backend:
  - @Recipients
  - @ccRecipients (optional)
  - @ServerID
  - @MonthsBack (default 6, clamped 1..12 in API)

  Prereqs:
  - Database Mail configured and enabled on this SQL Server
  - inventory.SQLDatabaseMonthlyMax is populated (scheduled collectors)

  Notes:
  - This procedure renders the report as an HTML table in the email body (similar to Health Report).
  - Update the default profile selection logic if your environment requires a specific profile.
*/
CREATE OR ALTER PROCEDURE inventory.usp_Email_DBTrend_Server
  @Recipients NVARCHAR(MAX),
  @ccRecipients NVARCHAR(MAX) = NULL,
  @ServerID INT,
  @MonthsBack INT = 6,
  @ProfileName SYSNAME = 'SQLMailProfile',
  @SubjectPrefix NVARCHAR(200) = N'SQL Database Trend'
AS
BEGIN
  SET NOCOUNT ON;

  IF @MonthsBack IS NULL OR @MonthsBack < 1 SET @MonthsBack = 6;
  IF @MonthsBack > 12 SET @MonthsBack = 12;

  DECLARE @ServerName NVARCHAR(200), @BU NVARCHAR(200), @Env NVARCHAR(50);
  SELECT
    @ServerName = s.ServerName,
    @BU = bu.BusinessUnitName,
    @Env = env.EnvName
  FROM inventory.Server s
  INNER JOIN inventory.BusinessUnit bu ON bu.BUID = s.BUID
  INNER JOIN inventory.Environment env ON env.EnvID = s.EnvID
  WHERE s.ServerID = @ServerID;

  IF @ServerName IS NULL
    RETURN;

  -- Pick a default Database Mail profile if not provided.
  IF @ProfileName IS NULL
  BEGIN
    SELECT TOP (1) @ProfileName = p.name
    FROM msdb.dbo.sysmail_profile p
    ORDER BY p.profile_id;
  END

  DECLARE @firstOfThisMonth DATE = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);
  DECLARE @startMonth DATE = DATEADD(MONTH, -(@MonthsBack - 1), @firstOfThisMonth);
  DECLARE @startYm CHAR(7) = CONVERT(CHAR(7), @startMonth, 120);      -- YYYY-MM
  DECLARE @endYm CHAR(7) = CONVERT(CHAR(7), @firstOfThisMonth, 120);  -- YYYY-MM

  DECLARE @months TABLE (SortOrder INT PRIMARY KEY, YearMonth CHAR(7) NOT NULL, Label NVARCHAR(20) NOT NULL);
  DECLARE @i INT = 0;
  WHILE @i < @MonthsBack
  BEGIN
    DECLARE @d DATE = DATEADD(MONTH, @i, @startMonth);
    INSERT INTO @months (SortOrder, YearMonth, Label)
    VALUES
    (
      @i,
      CONVERT(CHAR(7), @d, 120),
      LEFT(DATENAME(MONTH, @d), 3) + N'-' + CONVERT(NVARCHAR(4), YEAR(@d))
    );
    SET @i += 1;
  END

  -- Basic HTML escaping for free-text columns used in markup.
  DECLARE @escServer NVARCHAR(400) = REPLACE(REPLACE(REPLACE(@ServerName, N'&', N'&amp;'), N'<', N'&lt;'), N'>', N'&gt;');
  DECLARE @escBu NVARCHAR(400) = REPLACE(REPLACE(REPLACE(ISNULL(@BU, N''), N'&', N'&amp;'), N'<', N'&lt;'), N'>', N'&gt;');
  DECLARE @escEnv NVARCHAR(100) = REPLACE(REPLACE(REPLACE(ISNULL(@Env, N''), N'&', N'&amp;'), N'<', N'&lt;'), N'>', N'&gt;');

  DECLARE @html NVARCHAR(MAX) = N'';
  SET @html += N'<h2 style="margin-bottom:4px;">' + @escServer + N'</h2>';
  SET @html += N'<div style="color:#445; margin-bottom:10px;">' + @escBu + N' | ' + @escEnv + N'</div>';
  SET @html += N'<div style="color:#667; margin-bottom:12px;">Six-month comparison of monthly maximum database size, based on daily snapshots.</div>';
  SET @html += N'<div style="color:#667; margin-bottom:14px;">Range: ' + @startYm + N' to ' + @endYm + N' (MonthsBack=' + CONVERT(nvarchar(10), @MonthsBack) + N')</div>';

  SET @html += N'<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; font-family:Segoe UI, Arial; font-size:12px;">';
  SET @html += N'<tr style="background:#f3f6fb;">';
  SET @html += N'<th align="left">SQL Instance</th><th align="left">Database</th>';

  -- Month headers
  SELECT @html += (
    SELECT N'<th align="right">' + m.Label + N'</th>'
    FROM @months m
    ORDER BY m.SortOrder
    FOR XML PATH(''), TYPE
  ).value('.','nvarchar(max)');

  SET @html += N'<th align="right">% Change (6M)</th></tr>';

  ;WITH base AS (
    SELECT
      si.InstanceName,
      m.DatabaseName,
      m.YearMonth,
      CAST(m.MaxTotalSizeGB AS decimal(18,2)) AS MaxTotalSizeGB
    FROM inventory.SQLDatabaseMonthlyMax m
    INNER JOIN inventory.SQLInstance si ON si.SQLInstanceID = m.SQLInstanceID
    WHERE si.ServerID = @ServerID
      AND ISNULL(si.IsActive, 1) = 1
      AND m.YearMonth >= @startYm
      AND m.YearMonth <= @endYm
  ),
  combos AS (
    SELECT DISTINCT InstanceName, DatabaseName
    FROM base
  )
  SELECT @html += (
    SELECT
      N'<tr>' +
      N'<td>' + REPLACE(REPLACE(REPLACE(ISNULL(c.InstanceName, N''), N'&', N'&amp;'), N'<', N'&lt;'), N'>', N'&gt;') + N'</td>' +
      N'<td>' + REPLACE(REPLACE(REPLACE(ISNULL(c.DatabaseName, N''), N'&', N'&amp;'), N'<', N'&lt;'), N'>', N'&gt;') + N'</td>' +
      (
        SELECT
          N'<td align="right">' +
          ISNULL(CONVERT(nvarchar(32), v.MaxTotalSizeGB), N'') +
          N'</td>'
        FROM @months mm
        OUTER APPLY (
          SELECT TOP (1) b.MaxTotalSizeGB
          FROM base b
          WHERE b.InstanceName = c.InstanceName
            AND b.DatabaseName = c.DatabaseName
            AND b.YearMonth = mm.YearMonth
        ) v
        ORDER BY mm.SortOrder
        FOR XML PATH(''), TYPE
      ).value('.','nvarchar(max)') +
      (
        SELECT
          CASE
            WHEN s0.MaxTotalSizeGB IS NULL OR s1.MaxTotalSizeGB IS NULL OR s0.MaxTotalSizeGB <= 0 THEN N'<td align="right"></td>'
            ELSE
              CASE WHEN ((s1.MaxTotalSizeGB - s0.MaxTotalSizeGB) / s0.MaxTotalSizeGB) * 100.0 > 20
                THEN N'<td align="right" style="background:#f9e8ea; font-weight:700;">'
                ELSE N'<td align="right" style="background:#e9f8ef; font-weight:700;">'
              END +
              CONVERT(nvarchar(32), CAST(((s1.MaxTotalSizeGB - s0.MaxTotalSizeGB) / s0.MaxTotalSizeGB) * 100.0 AS decimal(18,2))) + N'%' +
              N'</td>'
          END
        FROM (SELECT TOP (1) b.MaxTotalSizeGB FROM base b WHERE b.InstanceName=c.InstanceName AND b.DatabaseName=c.DatabaseName AND b.YearMonth=@startYm) s0
        CROSS JOIN (SELECT TOP (1) b.MaxTotalSizeGB FROM base b WHERE b.InstanceName=c.InstanceName AND b.DatabaseName=c.DatabaseName AND b.YearMonth=@endYm) s1
      ) +
      N'</tr>'
    FROM combos c
    ORDER BY c.InstanceName, c.DatabaseName
    FOR XML PATH(''), TYPE
  ).value('.','nvarchar(max)');

  IF NOT EXISTS (
    SELECT 1
    FROM inventory.SQLDatabaseMonthlyMax m
    INNER JOIN inventory.SQLInstance si ON si.SQLInstanceID = m.SQLInstanceID
    WHERE si.ServerID = @ServerID
      AND ISNULL(si.IsActive, 1) = 1
      AND m.YearMonth >= @startYm
      AND m.YearMonth <= @endYm
  )
  BEGIN
    SET @html += N'<tr><td colspan="' + CONVERT(nvarchar(10), 3 + @MonthsBack) + N'" align="center" style="padding:12px; color:#667;">No trend data found for selected range.</td></tr>';
  END

  SET @html += N'</table>';

  DECLARE @emailsub NVARCHAR(500) = @SubjectPrefix + N' - ' +@ServerName;

  EXEC msdb.dbo.sp_send_dbmail
    @profile_name = @ProfileName,
    @recipients = @Recipients,
    @copy_recipients = @ccRecipients,
    @subject = @emailSub,
    @body = @html,
    @body_format = 'HTML';
END
GO
