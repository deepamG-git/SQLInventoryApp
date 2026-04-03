USE SQLInventory;
GO

/*
  Refreshes inventory.ServerStorage from remote servers via Linked Servers.
  Uses SQL Server volume stats (sys.dm_os_volume_stats) on a selected instance per server.

  Behavior per Server:
  - Deactivate existing active storage rows (IsActive=0)
  - Insert freshly fetched rows (IsActive=1)

  Instance selection per Server:
  - Prefer MSSQLSERVER if present and active
  - Else first active instance for that server

  Linked Server name resolution is the same as inventory.usp_Refresh_SQLDatabase_FromLinkedServers
  (via inventory.SQLInstanceLinkedServer or fallback naming convention).
*/

CREATE OR ALTER PROCEDURE inventory.usp_Refresh_ServerStorage_FromLinkedServers
  @OnlyBUID INT = NULL,
  @OnlyServerID INT = NULL
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
      COALESCE(
        l.LinkedServerName,
        CASE
          WHEN UPPER(si.InstanceName) = 'MSSQLSERVER' THEN s.ServerName
          ELSE s.ServerName + '\\' + si.InstanceName
        END
      ) AS LinkedServerName,
      ROW_NUMBER() OVER (
        PARTITION BY s.ServerID
        ORDER BY CASE WHEN UPPER(si.InstanceName) = 'MSSQLSERVER' THEN 0 ELSE 1 END, si.SQLInstanceID
      ) AS rn
    FROM inventory.Server s
    INNER JOIN inventory.SQLInstance si ON si.ServerID = s.ServerID AND ISNULL(si.IsActive, 1) = 1
    LEFT JOIN inventory.SQLInstanceLinkedServer l ON l.SQLInstanceID = si.SQLInstanceID AND l.IsActive = 1
    WHERE (@OnlyServerID IS NULL OR s.ServerID = @OnlyServerID)
      AND (@OnlyBUID IS NULL OR s.BUID = @OnlyBUID)
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
        VolumeMountPoint NVARCHAR(260) NOT NULL,
        LogicalVolumeName NVARCHAR(260) NULL,
        TotalSizeGB DECIMAL(18,2) NOT NULL,
        FreeSpaceGB DECIMAL(18,2) NOT NULL
      );

      SET @dyn = N'
        SELECT DISTINCT
          vs.volume_mount_point AS VolumeMountPoint,
          vs.logical_volume_name AS LogicalVolumeName,
          CAST(vs.total_bytes / 1024.0 / 1024.0 / 1024.0 AS decimal(18,2)) AS TotalSizeGB,
          CAST(vs.available_bytes / 1024.0 / 1024.0 / 1024.0 AS decimal(18,2)) AS FreeSpaceGB
        FROM ' + QUOTENAME(@Linked) + N'.master.sys.master_files mf
        CROSS APPLY ' + QUOTENAME(@Linked) + N'.master.sys.dm_os_volume_stats(mf.database_id, mf.file_id) vs;
      ';

      INSERT INTO #Vol
      EXEC sys.sp_executesql @dyn;

      UPDATE inventory.ServerStorage
      SET IsActive = 0
      WHERE ServerID = @ServerID AND IsActive = 1;

      MERGE inventory.ServerStorage AS tgt
      USING (
        SELECT
          @ServerID AS ServerID,
          LEFT(VolumeMountPoint, 1) AS DriveLetter,
          LEFT(ISNULL(LogicalVolumeName, ''), 100) AS VolumeLabel,
          TotalSizeGB,
          FreeSpaceGB
        FROM #Vol
        WHERE VolumeMountPoint LIKE '[A-Z]:\%'
      ) AS src
      ON tgt.ServerID = src.ServerID AND tgt.DriveLetter = src.DriveLetter
      WHEN MATCHED THEN
        UPDATE SET
          tgt.VolumeLabel = src.VolumeLabel,
          tgt.TotalSizeGB = src.TotalSizeGB,
          tgt.FreeSpaceGB = src.FreeSpaceGB,
          tgt.IsActive = 1
      WHEN NOT MATCHED THEN
        INSERT (ServerID, DriveLetter, VolumeLabel, TotalSizeGB, FreeSpaceGB, IsActive)
        VALUES (src.ServerID, src.DriveLetter, src.VolumeLabel, src.TotalSizeGB, src.FreeSpaceGB, 1);

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
