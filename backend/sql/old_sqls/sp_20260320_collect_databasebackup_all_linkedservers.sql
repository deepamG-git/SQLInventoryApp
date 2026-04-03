USE SQLInventory;
GO

/*
  Convenience wrapper to collect backups for all configured Linked Servers.
  Requires inventory.SQLInstanceLinkedServer to be populated (IsActive=1).
*/

CREATE OR ALTER PROCEDURE inventory.usp_Collect_DatabaseBackups_AllLinkedServers
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @ls SYSNAME;
  DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT DISTINCT LinkedServerName
    FROM inventory.SQLInstanceLinkedServer
    WHERE IsActive = 1
    ORDER BY LinkedServerName;

  OPEN cur;
  FETCH NEXT FROM cur INTO @ls;

  WHILE @@FETCH_STATUS = 0
  BEGIN
    BEGIN TRY
      EXEC inventory.usp_Collect_DatabaseBackups_Last24h @LinkedServerName = @ls;
    END TRY
    BEGIN CATCH
      PRINT CONCAT('Backup collect wrapper failed for LinkedServer=', @ls, ' Error=', ERROR_MESSAGE());
    END CATCH;

    FETCH NEXT FROM cur INTO @ls;
  END

  CLOSE cur;
  DEALLOCATE cur;
END
GO

