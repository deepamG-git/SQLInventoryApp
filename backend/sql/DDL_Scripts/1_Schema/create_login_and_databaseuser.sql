USE [master]
GO

/* For security reasons the login is created disabled and with a random password. */
CREATE LOGIN [Invent] WITH PASSWORD=N'xxxxxxxxxxxxxx', DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english], 
CHECK_EXPIRATION=OFF, CHECK_POLICY=ON
GO

ALTER LOGIN [Invent] DISABLE
GO


USE [SQLInventory]
GO
CREATE USER [Invent] FOR LOGIN [Invent] WITH DEFAULT_SCHEMA=[dbo]
GO
ALTER ROLE [db_owner] ADD MEMBER [Invent]
GO
GO
