/****** Object:  StoredProcedure [inventory].[usp_Sync_Database_PrimarySecondaryInstance]    Script Date: 03-04-2026 15:48:50 ******/
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
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
