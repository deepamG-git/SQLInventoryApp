SELECT *
  FROM [DBAdmin].[Archive].[tbl_DatabaseFileSpace]
  WHERE InstanceName = 'INDSRVDEVOPS-01'
  ORDER BY DataUpdatedOn ASC

--INSERT INTO SQLInventory.inventory.SQLDatabaseDailySnapshot
--(
--    SnapshotDate,
--    SQLInstanceID,
--    DatabaseName,
--    DataSizeGB,
--    LogSizeGB,
--    --TotalSizeGB,
--    CreatedDate
--)
--SELECT * FROM OPENQUERY(
--    [BI-PROD],
--     N'
--        SELECT
--            CAST(src.DataUpdatedOn AS DATE)                                                          AS SnapshotDate,
--            ''4'',
--            src.DatabaseName,
--            ROUND(SUM(CASE WHEN src.FileType = ''ROWS'' THEN src.TotalSizeMB ELSE 0 END) / 1024.0, 2) AS DataSizeGB,
--            ROUND(SUM(CASE WHEN src.FileType = ''LOG''  THEN src.TotalSizeMB ELSE 0 END) / 1024.0, 2) AS LogSizeGB,
--            --ROUND(SUM(src.TotalSizeMB) / 1024.0, 2)                                                 AS TotalSizeGB,
--            GETDATE()                                                                                AS CreatedDate
--        FROM [DBAdmin].[Archive].[tbl_DatabaseFileSpace] src                         -- ← replace with your actual source table
--        WHERE InstanceName = ''TJCAZPROD-DB01''
--        AND DataUpdatedOn >  ''2026-01-15''
--        AND DataUpdatedOn <=  ''2026-01-31''
--        --AND DataUpdatedOn > = DATEADD(month, -6, CAST(GETDATE() AS DATE))  -- last 6 months of data; adjust as needed
--        --AND DataUpdatedOn < = DATEADD(month, -5, CAST(GETDATE() AS DATE))
--        --JOIN SQLInventory.inventory.sqlinstance i
--        --    ON src.InstanceName = i.InstanceName             -- ← adjust join column if different
--        GROUP BY
--            CAST(src.DataUpdatedOn AS DATE),
--            --i.SQLInstanceID,
--            src.DatabaseName;
--    ');

INSERT INTO DBA_SQLInventory.inventory.SQLDatabaseDailySnapshot
(
    SnapshotDate,
    SQLInstanceID,
    DatabaseName,
    DataSizeGB,
    LogSizeGB,
    --TotalSizeGB,
    CreatedDate
)

        SELECT
            CAST(src.DataUpdatedOn AS DATE)                                                          AS SnapshotDate,
            '41',
            src.DatabaseName,
            ROUND(SUM(CASE WHEN src.FileType = 'ROWS' THEN src.TotalSizeMB ELSE 0 END) / 1024.0, 2) AS DataSizeGB,
            ROUND(SUM(CASE WHEN src.FileType = 'LOG'  THEN src.TotalSizeMB ELSE 0 END) / 1024.0, 2) AS LogSizeGB,
            --ROUND(SUM(src.TotalSizeMB) / 1024.0, 2)                                                 AS TotalSizeGB,
            GETDATE()                                                                                AS CreatedDate
        FROM [DBAdmin].[Archive].[tbl_DatabaseFileSpace] src                         -- ← replace with your actual source table
        WHERE InstanceName = 'VGLIND-DBSRV-01\JV3'
        AND DataUpdatedOn >  '2025-10-01'
        AND DataUpdatedOn <=  '2026-03-15'
        --AND DataUpdatedOn > = DATEADD(month, -6, CAST(GETDATE() AS DATE))  -- last 6 months of data; adjust as needed
        --AND DataUpdatedOn < = DATEADD(month, -5, CAST(GETDATE() AS DATE))
        --JOIN SQLInventory.inventory.sqlinstance i
        --    ON src.InstanceName = i.InstanceName             -- ← adjust join column if different
        GROUP BY
            CAST(src.DataUpdatedOn AS DATE),
            --i.SQLInstanceID,
            src.DatabaseName;
       

SELECT s.ServerName, s.Serverid, si.InstanceName, si.SQLInstanceID
FROM DBA_SQLInventory.inventory.Server s
JOIN DBA_SQLInventory.inventory.SQLInstance si ON s.ServerID = si.ServerID


SELECT * FROM inventory.SQLDatabase WHERE SQLInstanceID = 10

SELECT *  FROM inventory.SQLDatabaseDailySnapshot WHERE SQLInstanceID = 41
--AND SnapshotDate > '2025-12-31' AND SnapshotDate <= '2026-01-31'
--and DAtabaseName = 'CDBIntegrated'
ORDER BY DatabaseName, SnapshotDate

--UPDATE inventory.SQLDatabaseDailySnapshot
SET DataSizeGB = DataSizeGB/2, LogSizeGB = LogSizeGB/2
WHERE SQLInstanceID = 42
AND SnapshotDate IN ('2026-01-10')--,'2025-10-27','2026-01-06')
--'2025-11-29', '2025-12-06', '2025-12-13','2025-12-20','2025-12-27','2026-01-03','2026-01-10','2026-01-17','2026-01-24','2026-01-31',
--'2026-02-07','2026-02-14','2026-02-21','2026-02-28','2026-03-07','2026-03-14')

--EXEC inventory.usp_calc_SQLDatabaseMonthlyMax @MonthsBack = 6



--UPDATE inventory.ServerStorage SET ISActive = 1 WHERE ServerID = 12


SELECT *
  FROM [DBA_SQLInventory].[inventory].[SQLInstanceLinkedServer]

  --UPDATE inventory.SQLInstanceLinkedServer
  --SET LinkedServerName = '192.168.5.10\JMS', IsActive = 1, ModifiedDate = GETDATE(), ModifiedBy = SYSTEM_USER
  --WHERE SQLInstanceID = 12

--INSERT INTO [DBA_SQLInventory].[inventory].[SQLInstanceLinkedServer] 
--(SQLInstanceID, LinkedServerName, IsActive, CreatedBy)
--VALUES
--(39, '52.188.141.231', 1, SYSTEM_USER),
--(40, 'INDSRVDEVOPS-01',1, SYSTEM_USER),
--(41, 'VGLIND-DBSRV-01', 1, SYSTEM_USER),
--(7, 'SLCAMSPRODSQL.TJC.TV', 1, SYSTEM_USER),
--(4, 'TJCAMSPRODSQL.TJC.CO.UK', 1, SYSTEM_USER),
--(10, 'DEDBPROD.SHOPLCDE.TV', 1, SYSTEM_USER),
--(42, '192.168.7.14', 1, SYSTEM_USER);

--SQL Database refresh
EXEC inventory.usp_Refresh_SQLDatabase_FromLinkedServers @LinkedServerName = '192.168.5.10\JMS';    --JMS Database Server
EXEC inventory.usp_Refresh_SQLDatabase_FromLinkedServers @LinkedServerName = 'INDSRVDEVOPS-01';     --GMS Database Server
EXEC inventory.usp_Refresh_SQLDatabase_FromLinkedServers @LinkedServerName = '52.188.141.231';      --CDB Database Server
EXEC inventory.usp_Refresh_SQLDatabase_FromLinkedServers @LinkedServerName = 'VGLIND-DBSRV-01';     --JV3 Database Server
EXEC inventory.usp_Refresh_SQLDatabase_FromLinkedServers @LinkedServerName = '192.168.7.14';        --AI/BI Database Server

EXEC inventory.usp_Refresh_SQLDatabase_FromLinkedServers @LinkedServerName = 'SLCAMSPRODSQL.TJC.TV';    --SHOPLC-US Database Server
EXEC inventory.usp_Refresh_SQLDatabase_FromLinkedServers @LinkedServerName = 'TJCAMSPRODSQL.TJC.CO.UK'; --TJC-UK Database Server
EXEC inventory.usp_Refresh_SQLDatabase_FromLinkedServers @LinkedServerName = 'DEDBPROD.SHOPLCDE.TV';    --SHOPLC-DE Database Server

SELECT ModifiedDate,CreatedDate, * FROM inventory.SQLDatabase ORDER BY 1 DESC-- WHERE SQLInstanceID = 12
SELECT CreatedDate, * FROM inventory.SQLDAtabaseDailySnapshot ORDER BY 1 DESC

--Database Backup refresh
EXEC inventory.usp_Collect_DatabaseBackups_Last24h @LinkedServerName = '192.168.5.10\JMS';    --JMS Database Server
EXEC inventory.usp_Collect_DatabaseBackups_Last24h @LinkedServerName = 'INDSRVDEVOPS-01';     --GMS Database Server
EXEC inventory.usp_Collect_DatabaseBackups_Last24h @LinkedServerName = '52.188.141.231';      --CDB Database Server
EXEC inventory.usp_Collect_DatabaseBackups_Last24h @LinkedServerName = 'VGLIND-DBSRV-01';     --JV3 Database Server
EXEC inventory.usp_Collect_DatabaseBackups_Last24h @LinkedServerName = '192.168.7.14';        --AI/BI Database Server

EXEC inventory.usp_Collect_DatabaseBackups_Last24h @LinkedServerName = 'SLCAMSPRODSQL.TJC.TV';    --SHOPLC-US Database Server
EXEC inventory.usp_Collect_DatabaseBackups_Last24h @LinkedServerName = 'TJCAMSPRODSQL.TJC.CO.UK'; --TJC-UK Database Server
EXEC inventory.usp_Collect_DatabaseBackups_Last24h @LinkedServerName = 'DEDBPROD.SHOPLCDE.TV';    --SHOPLC-DE Database Server

SELECT CreatedDate, * FROM inventory.databasebackup ORDER BY 1 DESC--WHERE SQLInstanceID = 12

--SQL Maintenance Job refresh
EXEC inventory.usp_Collect_SQLMaintenanceJobs @LinkedServerName = '192.168.5.10\JMS';    --JMS Database Server
EXEC inventory.usp_Collect_SQLMaintenanceJobs @LinkedServerName = 'INDSRVDEVOPS-01';     --GMS Database Server
EXEC inventory.usp_Collect_SQLMaintenanceJobs @LinkedServerName = '52.188.141.231';      --CDB Database Server
EXEC inventory.usp_Collect_SQLMaintenanceJobs @LinkedServerName = 'VGLIND-DBSRV-01';     --JV3 Database Server
EXEC inventory.usp_Collect_SQLMaintenanceJobs @LinkedServerName = '192.168.7.14';        --AI/BI Database Server

EXEC inventory.usp_Collect_SQLMaintenanceJobs @LinkedServerName = 'SLCAMSPRODSQL.TJC.TV';    --SHOPLC-US Database Server
EXEC inventory.usp_Collect_SQLMaintenanceJobs @LinkedServerName = 'TJCAMSPRODSQL.TJC.CO.UK'; --TJC-UK Database Server
EXEC inventory.usp_Collect_SQLMaintenanceJobs @LinkedServerName = 'DEDBPROD.SHOPLCDE.TV';    --SHOPLC-DE Database Server


SELECT * FROM inventory.SQLMaintenanceJobRun WHERE SQLInstanceID = 7 ORDER BY SnapshotDate DESC, JobName



-- Server Storage refresh(excluding C Drive)
EXEC inventory.usp_Refresh_ServerStorage_FromLinkedServers @LinkedServerName = '192.168.5.10\JMS';          --JMS Database Server    
EXEC inventory.usp_Refresh_ServerStorage_FromLinkedServers @LinkedServerName = 'INDSRVDEVOPS-01';           --GMS Database Server
EXEC inventory.usp_Refresh_ServerStorage_FromLinkedServers @LinkedServerName = '52.188.141.231';            --CDB Database Server
EXEC inventory.usp_Refresh_ServerStorage_FromLinkedServers @LinkedServerName = 'VGLIND-DBSRV-01';           --JV3 Database Server
EXEC inventory.usp_Refresh_ServerStorage_FromLinkedServers @LinkedServerName = '192.168.7.14';              --AI/BI Database Server

EXEC inventory.usp_Refresh_ServerStorage_FromLinkedServers @LinkedServerName = 'SLCAMSPRODSQL.TJC.TV';      --SHOPLC-US Database Server
EXEC inventory.usp_Refresh_ServerStorage_FromLinkedServers @LinkedServerName = 'TJCAMSPRODSQL.TJC.CO.UK';   --TJC-UK Database Server
EXEC inventory.usp_Refresh_ServerStorage_FromLinkedServers @LinkedServerName = 'DEDBPROD.SHOPLCDE.TV';      --SHOPLC-DE Database Server

SELECT * FROM inventory.ServerStorage WHERE ServerID = 12

USE [master]
GO
EXEC master.dbo.sp_serveroption @server=N'192.168.7.14', @optname=N'rpc', @optvalue=N'true'
GO
EXEC master.dbo.sp_serveroption @server=N'192.168.7.14', @optname=N'rpc out', @optvalue=N'true'
GO
EXEC master.dbo.sp_serveroption @server=N'192.168.7.14', @optname=N'remote proc transaction promotion', @optvalue=N'false'



EXEC inventory.usp_Email_HealthReport_Server
  @ServerID = 12,
  @Recipients = 'deepam.ghosh@vglgroup.com',
  @ccRecipients = '';

-- 3) Send health reports for all PROD + IN USE servers (optionally per BU)
EXEC inventory.usp_Email_HealthReport_Prod
  @ProfileName = 'DBA_mail',
  @Recipients = 'dba-team@company.com',
  @OnlyBUID = NULL;  -- or a BU id


EXEC [inventory].[usp_Sync_Database_PrimarySecondaryInstance]
    @PrimarySQLInstanceID = 7, --10:DE-P, 22:DE-S, 4:UK-P, 19:UK-S
    @SecondarySQLInstanceID = 26    

    USE [DBA_SQLInventory];
GO


--- Delete feature
SELECT * FROM inventory.SQLMaintenanceJobRun

DELETE 	FROM inventory.SQLMaintenanceJobRun
WHERE SnapshotDate < DATEADD(DAY, -7, CAST(GETDATE() AS DATE));  --keep 7 days of jobs history

SELECT * FROM inventory.serverstorage

select * from inventory.databasebackup order by createddate asc

DELETE FROM inventory.databasebackup
WHERE BackupStartDate < DATEADD(DAY, -30, GETDATE())  --Keep 30 days of backup history

select * from inventory.sqldatabase

select FORMAT(SnapshotDAte, 'MMM yyyy'),COUNT(SnapshotDate)  
from inventory.sqldatabasedailysnapshot
GROUP BY FORMAT(SnapshotDAte, 'MMM yyyy')

DELETE FROM inventory.sqldatabasedailysnapshot
WHERE SnapshotDate < DATEADD(DAY, -365, GETDATE())  --Keep 365 days of daily snapshots history


