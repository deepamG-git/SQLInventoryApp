/****** Object:  StoredProcedure [inventory].[usp_Collect_DatabaseBackups_Last24h]    Script Date: 03-04-2026 15:48:50 ******/
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON

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


