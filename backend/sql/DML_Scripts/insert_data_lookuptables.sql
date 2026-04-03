USE [SQLInventory]
GO

/* Sample Values for Lookup Tables */

-- Inventory Lookup Table
INSERT [inventory].[BusinessUnit] ([BUID], [BusinessUnitName]) VALUES (1, N'BU-1')
GO
INSERT [inventory].[BusinessUnit] ([BUID], [BusinessUnitName]) VALUES (2, N'BU-2')
GO


-- Environment Lookup Table
INSERT [inventory].[Environment] ([EnvID], [EnvName]) VALUES (1, N'DEV')
GO
INSERT [inventory].[Environment] ([EnvID], [EnvName]) VALUES (2, N'PROD')
GO

-- Region Lookup Table
INSERT [inventory].[Region] ([RegionID], [RegionName]) VALUES (1, N'India')
GO
INSERT [inventory].[Region] ([RegionID], [RegionName]) VALUES (2, N'US')
GO

-- ServerCategory Lookup Table
INSERT [inventory].[ServerCategory] ([CategoryID], [CategoryName]) VALUES (1, N'Database Server')
GO
INSERT [inventory].[ServerCategory] ([CategoryID], [CategoryName]) VALUES (4, N'Database/ETL Server')
GO
INSERT [inventory].[ServerCategory] ([CategoryID], [CategoryName]) VALUES (3, N'Database/Reporting Server')
GO

-- ServerStatus Lookup Table
INSERT [inventory].[ServerStatus] ([StatusID], [StatusName]) VALUES (1, N'IN USE')
GO
INSERT [inventory].[ServerStatus] ([StatusID], [StatusName]) VALUES (2, N'TO BE COMMISSIONED')
GO
INSERT [inventory].[ServerStatus] ([StatusID], [StatusName]) VALUES (3, N'DECOMMISSIONED')
GO

-- Contact Lookup Table
INSERT [inventory].[Contact] ([ContactID], [ContactName], [Email], [Phone]) VALUES (1, N'User 1', N'user1@example.com', N'N/A')
GO
INSERT [inventory].[Contact] ([ContactID], [ContactName], [Email], [Phone]) VALUES (2, N'User 2', N'user2@example.com', N'N/A')
GO

-- ContactCategory lookup table
INSERT [inventory].[ContactCategory] ([ContactCategoryID], [ContactCategoryName]) VALUES (1, N'DBA Owner')
GO
INSERT [inventory].[ContactCategory] ([ContactCategoryID], [ContactCategoryName]) VALUES (2, N'Infra Owner')
GO
INSERT [inventory].[ContactCategory] ([ContactCategoryID], [ContactCategoryName]) VALUES (3, N'App Owner')
GO


-- Domain Lookup Table
INSERT [inventory].[Domain] ([DomainID], [DomainName]) VALUES (1, N'domain1.org')
GO
INSERT [inventory].[Domain] ([DomainID], [DomainName]) VALUES (2, N'domain2.in')
GO

-- OSType Lookup Table
INSERT [inventory].[OSType] ([OSID], [OperatingSystem], [OSCategory]) VALUES (1, N'Microsoft Windows Server 2022 Standard', N'Windows')
GO
INSERT [inventory].[OSType] ([OSID], [OperatingSystem], [OSCategory]) VALUES (3, N'Red Hat Enterprise Linux 8.4', N'Linux')
GO

-- Platform Lookup Table
INSERT [inventory].[Platform] ([PlatformID], [PlatformName]) VALUES (1, N'Azure VM')
GO
INSERT [inventory].[Platform] ([PlatformID], [PlatformName]) VALUES (2, N'On-Prem VM')
GO

-- ServerType Lookup Table
INSERT [inventory].[ServerType] ([ServerTypeID], [ServerType]) VALUES (1, N'AlwaysON Cluster Node')
GO
INSERT [inventory].[ServerType] ([ServerTypeID], [ServerType]) VALUES (2, N'Standalone')
GO

-- Timezone Lookup Table
INSERT [inventory].[Timezone] ([TimezoneID], [Timezone]) VALUES (1, N'(UTC+00:00) Dublin, Edinburgh, Lisbon, London')
GO
INSERT [inventory].[Timezone] ([TimezoneID], [Timezone]) VALUES (2, N'(UTC+05:30) Chennai, Kolkata, Mumbai, New Delhi')
GO


-- IPAddressType Lookup Table
INSERT [inventory].[IPAddressType] ([IPAddressTypeID], [TypeName]) VALUES (1, N'Listener')
GO
INSERT [inventory].[IPAddressType] ([IPAddressTypeID], [TypeName]) VALUES (2, N'Private')
GO
INSERT [inventory].[IPAddressType] ([IPAddressTypeID], [TypeName]) VALUES (3, N'Public')
GO

-- SQLInstanceType Lookup Table
INSERT [inventory].[SQLInstanceType] ([InstanceTypeID], [InstanceTypeName]) VALUES (1, N'Default Instance')
GO
INSERT [inventory].[SQLInstanceType] ([InstanceTypeID], [InstanceTypeName]) VALUES (2, N'Named Instance')
GO

-- SQLEdition Lookup Table
INSERT [inventory].[SQLEdition] ([SQLEditionID], [SQLEditionName]) VALUES (1, N'Developer Edition')
GO
INSERT [inventory].[SQLEdition] ([SQLEditionID], [SQLEditionName]) VALUES (2, N'Enterprise Edition')
GO

-- SQLVersion Lookup Table
INSERT [inventory].[SQLVersion] ([SQLVersionID], [SQLVersionName]) VALUES (1, N'SQL Server 2016')
GO
INSERT [inventory].[SQLVersion] ([SQLVersionID], [SQLVersionName]) VALUES (2, N'SQL Server 2017')
GO

-- SQLInstanceCollation Lookup Table
INSERT [inventory].[SQLInstanceCollation] ([InstanceCollationID], [InstanceCollationName]) VALUES (1, N'SQL_Latin1_General_CP1_CI_AI')
GO
INSERT [inventory].[SQLInstanceCollation] ([InstanceCollationID], [InstanceCollationName]) VALUES (2, N'SQL_Latin1_General_CP1_CI_AS')


-- SQLInstanceLinkedServer Lookup Table
INSERT [inventory].[SQLInstanceLinkedServer] ([SQLInstanceID], [LinkedServerName], [IsActive], [CreatedDate], [CreatedBy], [ModifiedDate], [ModifiedBy]) VALUES (1, N'LinkedSever1', 1, GETDATE(), SYSTEM_USER, NULL, NULL)
GO
INSERT [inventory].[SQLInstanceLinkedServer] ([SQLInstanceID], [LinkedServerName], [IsActive], [CreatedDate], [CreatedBy], [ModifiedDate], [ModifiedBy]) VALUES (2, N'LinkedSever2', 1, GETDATE(), SYSTEM_USER, NULL, NULL)
GO

-- AppUser Table
INSERT [inventory].[AppUser] ([UserID], [Username], [PasswordHash], [PasswordSalt], [IsActive], [CreatedDate], [UserRole]) VALUES (1, N'User1', N'xxxxxxxxxxxxxxxxxxxxxxxxxxxxx', N'QQQQQQQQ-XXXX-YYYY-YYYY-ZZZZZZZZZZZZ', 1, GETDATE(), N'readonly')
GO
INSERT [inventory].[AppUser] ([UserID], [Username], [PasswordHash], [PasswordSalt], [IsActive], [CreatedDate], [UserRole]) VALUES (2, N'User2', N'xxxxxxxxxxxxxxxxxxxxxxxxxxxxx', N'QQQQQQQQ-XXXX-YYYY-YYYY-ZZZZZZZZZZZZ', 1, GETDATE(), N'admin')
GO
