USE SQLInventory;
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
  - Linked Servers must be created on this central SQLInventory host with RPC/queries enabled.
*/

CREATE OR ALTER PROCEDURE inventory.usp_Refresh_SQLDatabase_FromLinkedServers
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
    COALESCE(
      l.LinkedServerName,
      CASE
        WHEN UPPER(si.InstanceName) = 'MSSQLSERVER' THEN s.ServerName
        ELSE s.ServerName + '\\' + si.InstanceName
      END
    ) AS LinkedServerName
  FROM inventory.SQLInstance si
  INNER JOIN inventory.Server s ON s.ServerID = si.ServerID
  LEFT JOIN inventory.SQLInstanceLinkedServer l ON l.SQLInstanceID = si.SQLInstanceID AND l.IsActive = 1
  WHERE ISNULL(si.IsActive, 1) = 1
    AND (@OnlySQLInstanceID IS NULL OR si.SQLInstanceID = @OnlySQLInstanceID)
    AND (@OnlyServerID IS NULL OR s.ServerID = @OnlyServerID)
    AND (@OnlyBUID IS NULL OR s.BUID = @OnlyBUID);

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

