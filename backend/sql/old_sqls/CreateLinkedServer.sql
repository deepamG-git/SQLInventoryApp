USE [master]
GO
EXEC master.dbo.sp_addlinkedserver @server = N'JMS-PROD', @srvproduct=N'', @provider=N'MSOLEDBSQL19', @datasrc=N'JMS-SRV\JMS', @provstr=N'TrustServerCertificate=Yes'

GO
EXEC master.dbo.sp_serveroption @server=N'JMS-PROD', @optname=N'collation compatible', @optvalue=N'false'
GO
EXEC master.dbo.sp_serveroption @server=N'JMS-PROD', @optname=N'data access', @optvalue=N'true'
GO
EXEC master.dbo.sp_serveroption @server=N'JMS-PROD', @optname=N'dist', @optvalue=N'false'
GO
EXEC master.dbo.sp_serveroption @server=N'JMS-PROD', @optname=N'pub', @optvalue=N'false'
GO
EXEC master.dbo.sp_serveroption @server=N'JMS-PROD', @optname=N'rpc', @optvalue=N'true'
GO
EXEC master.dbo.sp_serveroption @server=N'JMS-PROD', @optname=N'rpc out', @optvalue=N'true'
GO
EXEC master.dbo.sp_serveroption @server=N'JMS-PROD', @optname=N'sub', @optvalue=N'false'
GO
EXEC master.dbo.sp_serveroption @server=N'JMS-PROD', @optname=N'connect timeout', @optvalue=N'0'
GO
EXEC master.dbo.sp_serveroption @server=N'JMS-PROD', @optname=N'collation name', @optvalue=null
GO
EXEC master.dbo.sp_serveroption @server=N'JMS-PROD', @optname=N'lazy schema validation', @optvalue=N'false'
GO
EXEC master.dbo.sp_serveroption @server=N'JMS-PROD', @optname=N'query timeout', @optvalue=N'0'
GO
EXEC master.dbo.sp_serveroption @server=N'JMS-PROD', @optname=N'use remote collation', @optvalue=N'true'
GO
EXEC master.dbo.sp_serveroption @server=N'JMS-PROD', @optname=N'remote proc transaction promotion', @optvalue=N'true'
GO
USE [master]
GO
EXEC master.dbo.sp_addlinkedsrvlogin @rmtsrvname = N'JMS-PROD', @locallogin = NULL , @useself = N'False', @rmtuser = N'DataCollector', @rmtpassword = N'DBAUser@1234'
GO
