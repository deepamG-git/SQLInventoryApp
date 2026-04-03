USE SQLInventory;
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

CREATE OR ALTER PROCEDURE inventory.usp_Email_HealthReport_Server
  @ProfileName SYSNAME,
  @Recipients NVARCHAR(MAX),
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
      ORDER BY i.InstanceName, j.JobName
      FOR XML PATH(''), TYPE
    ).value('.','nvarchar(max)');
  END

  SET @html += N'</table>';

  EXEC msdb.dbo.sp_send_dbmail
    @profile_name = @ProfileName,
    @recipients = @Recipients,
    @subject = @SubjectPrefix + N' - ' + @ServerName,
    @body = @html,
    @body_format = 'HTML';
END
GO


CREATE OR ALTER PROCEDURE inventory.usp_Email_HealthReport_Prod
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

