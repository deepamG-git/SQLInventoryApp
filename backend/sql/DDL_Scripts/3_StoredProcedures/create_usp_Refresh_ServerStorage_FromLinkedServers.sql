/****** Object:  StoredProcedure [inventory].[usp_Refresh_ServerStorage_FromLinkedServers]    Script Date: 03-04-2026 15:48:50 ******/
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON

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


