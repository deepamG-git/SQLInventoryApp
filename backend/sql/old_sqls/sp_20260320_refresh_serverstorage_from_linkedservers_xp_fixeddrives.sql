USE SQLInventory;
GO

/*
  Refreshes inventory.ServerStorage from remote servers via a given Linked Server name.

  Goal: include OS drive (C:) even if no SQL files are on that drive.

  How it works:
  1) Uses sys.dm_os_volume_stats (via sys.master_files) to get Total+Free for drives that host SQL files.
  2) Uses master..xp_fixeddrives to get Free space for ALL fixed drives (includes C:).
  3) Merges the two:
     - If TotalSizeGB is NULL (from xp_fixeddrives-only), we keep existing TotalSizeGB from inventory.ServerStorage (so UI can still compute Free%).

  Notes:
  - Requires Linked Server to allow OPENQUERY.
  - xp_fixeddrives returns Free MB only (no total).
*/

CREATE OR ALTER PROCEDURE inventory.usp_Refresh_ServerStorage_FromLinkedServers
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
    INNER JOIN inventory.SQLInstance si ON si.ServerID = s.ServerID AND ISNULL(si.IsActive, 1) = 1
    INNER JOIN inventory.SQLInstanceLinkedServer l ON l.SQLInstanceID = si.SQLInstanceID AND l.IsActive = 1
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
        TotalSizeGB DECIMAL(18,2) NULL,
        FreeSpaceGB DECIMAL(18,2) NOT NULL,
        CONSTRAINT PK_#Vol PRIMARY KEY (DriveLetter)
      );

      -- 1) Drives hosting SQL files (has Total+Free)
      -- NOTE: You cannot call sys.dm_os_volume_stats remotely via 4-part names.
      -- Run the query on the remote server and insert the result locally via EXEC ... AT.
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

      SET @dyn = N'INSERT INTO #Vol (DriveLetter, VolumeLabel, TotalSizeGB, FreeSpaceGB)
                  EXEC (N''' + REPLACE(@remoteVol, '''', '''''') + N''') AT ' + QUOTENAME(@Linked) + N';';
      EXEC sys.sp_executesql @dyn;

      -- 2) All fixed drives free-space (includes C:). Total size is not available here.
      IF OBJECT_ID('tempdb..#FD') IS NOT NULL DROP TABLE #FD;
      CREATE TABLE #FD (DriveLetter CHAR(1) NOT NULL PRIMARY KEY, FreeSpaceGB DECIMAL(18,2) NOT NULL);

      -- Avoid OPENQUERY metadata issues with extended procs by executing a remote batch
      -- that materializes xp_fixeddrives output into a table variable and SELECTs typed columns.
      DECLARE @remoteFD NVARCHAR(MAX) = N'
        SET NOCOUNT ON;
        DECLARE @t TABLE (drive varchar(10), free_mb int);
        INSERT INTO @t EXEC master..xp_fixeddrives;
        SELECT LEFT(drive,1) AS DriveLetter,
               CAST(free_mb/1024.0 AS decimal(18,2)) AS FreeSpaceGB
        FROM @t
        WHERE drive LIKE ''[A-Z]%'';';

      DECLARE @dyn2 NVARCHAR(MAX) =
        N'INSERT INTO #FD (DriveLetter, FreeSpaceGB)
          EXEC (N''' + REPLACE(@remoteFD, '''', '''''') + N''') AT ' + QUOTENAME(@Linked) + N';';

      EXEC sys.sp_executesql @dyn2;

      -- Add any drives missing from #Vol (C: typically), and update free space for those present.
      MERGE #Vol AS tgt
      USING #FD AS src
      ON tgt.DriveLetter = src.DriveLetter
      WHEN MATCHED THEN
        UPDATE SET tgt.FreeSpaceGB = src.FreeSpaceGB
      WHEN NOT MATCHED THEN
        INSERT (DriveLetter, VolumeLabel, TotalSizeGB, FreeSpaceGB)
        VALUES (src.DriveLetter, NULL, NULL, src.FreeSpaceGB);

      -- Deactivate previous active rows
      UPDATE inventory.ServerStorage
      SET IsActive = 0
      WHERE ServerID = @ServerID AND IsActive = 1;

      -- Upsert per drive; if TotalSizeGB is NULL, keep existing TotalSizeGB to allow Free% calculation.
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
          tgt.TotalSizeGB = COALESCE(src.TotalSizeGB, tgt.TotalSizeGB),
          tgt.FreeSpaceGB = src.FreeSpaceGB,
          tgt.IsActive = 1
      WHEN NOT MATCHED THEN
        INSERT (ServerID, DriveLetter, VolumeLabel, TotalSizeGB, FreeSpaceGB, IsActive)
        VALUES (src.ServerID, src.DriveLetter, src.VolumeLabel, COALESCE(src.TotalSizeGB, 0), src.FreeSpaceGB, 1);

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
