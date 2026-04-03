USE [SQLInventory]
GO
/****** Object:  Table [inventory].[AppUser]    Script Date: 4/2/2026 4:32:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [inventory].[AppUser](
	[UserID] [int] IDENTITY(1,1) NOT NULL,
	[Username] [varchar](100) NOT NULL,
	[PasswordHash] [varchar](64) NOT NULL,
	[PasswordSalt] [varchar](64) NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedDate] [datetime2](7) NOT NULL,
	[UserRole] [varchar](20) NOT NULL,
 CONSTRAINT [PK_AppUser] PRIMARY KEY CLUSTERED 
(
	[UserID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [inventory].[BusinessUnit]    Script Date: 4/2/2026 4:32:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [inventory].[BusinessUnit](
	[BUID] [int] IDENTITY(1,1) NOT NULL,
	[BusinessUnitName] [varchar](100) NOT NULL,
 CONSTRAINT [PK_BusinessUnit] PRIMARY KEY CLUSTERED 
(
	[BUID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [inventory].[BusinessUnitContact]    Script Date: 4/2/2026 4:32:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [inventory].[BusinessUnitContact](
	[BUID] [int] NOT NULL,
	[ContactID] [int] NOT NULL,
	[ContactCategoryID] [int] NOT NULL,
 CONSTRAINT [PK_BUContact] PRIMARY KEY CLUSTERED 
(
	[BUID] ASC,
	[ContactID] ASC,
	[ContactCategoryID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [inventory].[ChangeHistory]    Script Date: 4/2/2026 4:32:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [inventory].[ChangeHistory](
	[ChangeID] [int] IDENTITY(1,1) NOT NULL,
	[EntityName] [varchar](100) NOT NULL,
	[RecordID] [int] NOT NULL,
	[FieldName] [varchar](100) NOT NULL,
	[OldValue] [varchar](max) NULL,
	[NewValue] [varchar](max) NULL,
	[ChangedBy] [varchar](100) NOT NULL,
	[ChangedDate] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_ChangeHistory] PRIMARY KEY CLUSTERED 
(
	[ChangeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [inventory].[Contact]    Script Date: 4/2/2026 4:32:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [inventory].[Contact](
	[ContactID] [int] IDENTITY(1,1) NOT NULL,
	[ContactName] [varchar](150) NOT NULL,
	[Email] [varchar](150) NULL,
	[Phone] [varchar](50) NULL,
 CONSTRAINT [PK_Contact] PRIMARY KEY CLUSTERED 
(
	[ContactID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [inventory].[ContactCategory]    Script Date: 4/2/2026 4:32:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [inventory].[ContactCategory](
	[ContactCategoryID] [int] IDENTITY(1,1) NOT NULL,
	[ContactCategoryName] [varchar](100) NOT NULL,
 CONSTRAINT [PK_ContactCategory] PRIMARY KEY CLUSTERED 
(
	[ContactCategoryID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [inventory].[DatabaseBackup]    Script Date: 4/2/2026 4:32:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [inventory].[DatabaseBackup](
	[DatabaseBackupID] [bigint] IDENTITY(1,1) NOT NULL,
	[SQLInstanceID] [int] NOT NULL,
	[DatabaseName] [varchar](256) NOT NULL,
	[BackupType] [char](1) NOT NULL,
	[BackupStartDate] [datetime2](7) NOT NULL,
	[BackupFinishDate] [datetime2](7) NOT NULL,
	[BackupSizeMB] [decimal](18, 2) NULL,
	[IsCopyOnly] [bit] NOT NULL,
	[BackupSetID] [int] NOT NULL,
	[CollectedDate] [date] NOT NULL,
	[CreatedDate] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_DatabaseBackup] PRIMARY KEY CLUSTERED 
(
	[DatabaseBackupID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [inventory].[Domain]    Script Date: 4/2/2026 4:32:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [inventory].[Domain](
	[DomainID] [int] IDENTITY(1,1) NOT NULL,
	[DomainName] [varchar](100) NOT NULL,
 CONSTRAINT [PK_Domain] PRIMARY KEY CLUSTERED 
(
	[DomainID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [inventory].[Environment]    Script Date: 4/2/2026 4:32:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [inventory].[Environment](
	[EnvID] [int] IDENTITY(1,1) NOT NULL,
	[EnvName] [varchar](50) NOT NULL,
 CONSTRAINT [PK_Environment] PRIMARY KEY CLUSTERED 
(
	[EnvID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [inventory].[IPAddressType]    Script Date: 4/2/2026 4:32:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [inventory].[IPAddressType](
	[IPAddressTypeID] [int] IDENTITY(1,1) NOT NULL,
	[TypeName] [varchar](50) NOT NULL,
 CONSTRAINT [PK_IPAddressType] PRIMARY KEY CLUSTERED 
(
	[IPAddressTypeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [inventory].[OSType]    Script Date: 4/2/2026 4:32:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [inventory].[OSType](
	[OSID] [int] IDENTITY(1,1) NOT NULL,
	[OperatingSystem] [varchar](100) NOT NULL,
	[OSCategory] [varchar](30) NULL,
 CONSTRAINT [PK_OSType] PRIMARY KEY CLUSTERED 
(
	[OSID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [inventory].[Platform]    Script Date: 4/2/2026 4:32:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [inventory].[Platform](
	[PlatformID] [int] IDENTITY(1,1) NOT NULL,
	[PlatformName] [varchar](100) NOT NULL,
 CONSTRAINT [PK_Platform] PRIMARY KEY CLUSTERED 
(
	[PlatformID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [inventory].[Region]    Script Date: 4/2/2026 4:32:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [inventory].[Region](
	[RegionID] [int] IDENTITY(1,1) NOT NULL,
	[RegionName] [varchar](100) NOT NULL,
 CONSTRAINT [PK_Region] PRIMARY KEY CLUSTERED 
(
	[RegionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [inventory].[Server]    Script Date: 4/2/2026 4:32:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [inventory].[Server](
	[ServerID] [int] IDENTITY(1,1) NOT NULL,
	[ServerName] [varchar](150) NOT NULL,
	[Description] [varchar](255) NULL,
	[EnvID] [int] NOT NULL,
	[BUID] [int] NOT NULL,
	[CategoryID] [int] NOT NULL,
	[RegionID] [int] NOT NULL,
	[StatusID] [int] NOT NULL,
	[CreatedDate] [datetime2](7) NOT NULL,
	[CreatedBy] [varchar](100) NOT NULL,
	[ModifiedDate] [datetime2](7) NULL,
	[ModifiedBy] [varchar](100) NULL,
 CONSTRAINT [PK_Server] PRIMARY KEY CLUSTERED 
(
	[ServerID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [inventory].[ServerCategory]    Script Date: 4/2/2026 4:32:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [inventory].[ServerCategory](
	[CategoryID] [int] IDENTITY(1,1) NOT NULL,
	[CategoryName] [varchar](100) NOT NULL,
 CONSTRAINT [PK_ServerCategory] PRIMARY KEY CLUSTERED 
(
	[CategoryID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [inventory].[ServerContact]    Script Date: 4/2/2026 4:32:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [inventory].[ServerContact](
	[ServerID] [int] NOT NULL,
	[ContactID] [int] NOT NULL,
	[ContactCategoryID] [int] NOT NULL,
	[CreatedDate] [datetime2](7) NOT NULL,
	[CreatedBy] [varchar](100) NULL,
 CONSTRAINT [PK_ServerContact] PRIMARY KEY CLUSTERED 
(
	[ServerID] ASC,
	[ContactID] ASC,
	[ContactCategoryID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [inventory].[ServerHardware]    Script Date: 4/2/2026 4:32:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [inventory].[ServerHardware](
	[ServerHardwareID] [int] IDENTITY(1,1) NOT NULL,
	[ServerID] [int] NOT NULL,
	[DomainID] [int] NOT NULL,
	[OperatingSystemID] [int] NOT NULL,
	[MemoryGB] [int] NOT NULL,
	[CPUCores] [int] NOT NULL,
	[ProcessorModel] [varchar](256) NOT NULL,
	[ServerTypeID] [int] NOT NULL,
	[PlatformID] [int] NOT NULL,
	[TimezoneID] [int] NOT NULL,
	[OSInstallDate] [date] NULL,
	[IsCurrent] [bit] NOT NULL,
	[EffectiveDate] [date] NOT NULL,
	[CreatedDate] [datetime2](7) NOT NULL,
	[CreatedBy] [varchar](100) NOT NULL,
	[ModifiedDate] [datetime2](7) NULL,
	[ModifiedBy] [varchar](100) NULL,
 CONSTRAINT [PK_ServerHardware] PRIMARY KEY CLUSTERED 
(
	[ServerHardwareID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [inventory].[ServerIP]    Script Date: 4/2/2026 4:32:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [inventory].[ServerIP](
	[IPID] [int] IDENTITY(1,1) NOT NULL,
	[ServerID] [int] NOT NULL,
	[IPAddress] [varchar](50) NOT NULL,
	[IPAddressTypeID] [int] NOT NULL,
	[IsActive] [bit] NOT NULL,
 CONSTRAINT [PK_ServerIP] PRIMARY KEY CLUSTERED 
(
	[IPID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [inventory].[ServerStatus]    Script Date: 4/2/2026 4:32:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [inventory].[ServerStatus](
	[StatusID] [int] IDENTITY(1,1) NOT NULL,
	[StatusName] [varchar](50) NOT NULL,
 CONSTRAINT [PK_ServerStatus] PRIMARY KEY CLUSTERED 
(
	[StatusID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [inventory].[ServerStorage]    Script Date: 4/2/2026 4:32:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [inventory].[ServerStorage](
	[StorageID] [int] IDENTITY(1,1) NOT NULL,
	[ServerID] [int] NOT NULL,
	[DriveLetter] [char](1) NOT NULL,
	[VolumeLabel] [varchar](100) NULL,
	[TotalSizeGB] [decimal](18, 2) NOT NULL,
	[FreeSpaceGB] [decimal](18, 2) NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedDate] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_ServerStorage] PRIMARY KEY CLUSTERED 
(
	[StorageID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [inventory].[ServerType]    Script Date: 4/2/2026 4:32:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [inventory].[ServerType](
	[ServerTypeID] [int] IDENTITY(1,1) NOT NULL,
	[ServerType] [varchar](100) NOT NULL,
 CONSTRAINT [PK_ServerType] PRIMARY KEY CLUSTERED 
(
	[ServerTypeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [inventory].[SQLDatabase]    Script Date: 4/2/2026 4:32:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [inventory].[SQLDatabase](
	[SQLDatabaseID] [int] IDENTITY(1,1) NOT NULL,
	[SQLInstanceID] [int] NOT NULL,
	[DatabaseName] [varchar](256) NOT NULL,
	[Owner] [varchar](128) NULL,
	[SizeGB] [decimal](18, 2) NULL,
	[CreatedOn] [datetime2](7) NULL,
	[RecoveryModel] [varchar](30) NULL,
	[DatabaseCollation] [varchar](128) NULL,
	[CDC] [bit] NOT NULL,
	[CompatibilityLevel] [int] NULL,
	[Encryption] [bit] NOT NULL,
	[QueryStore] [bit] NOT NULL,
	[AutoUpdateStats] [bit] NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedDate] [datetime2](7) NOT NULL,
	[CreatedBy] [varchar](100) NULL,
	[ModifiedDate] [datetime2](7) NULL,
	[ModifiedBy] [varchar](100) NULL,
	[DataSizeGB] [decimal](18, 2) NULL,
	[LogSizeGB] [decimal](18, 2) NULL,
	[TotalSizeGB]  AS (case when [DataSizeGB] IS NULL AND [LogSizeGB] IS NULL then isnull([SizeGB],(0)) else isnull([DataSizeGB],(0))+isnull([LogSizeGB],(0)) end) PERSISTED,
 CONSTRAINT [PK_SQLDatabase] PRIMARY KEY CLUSTERED 
(
	[SQLDatabaseID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [inventory].[SQLDatabaseDailySnapshot]    Script Date: 4/2/2026 4:32:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [inventory].[SQLDatabaseDailySnapshot](
	[SnapshotDate] [date] NOT NULL,
	[SQLInstanceID] [int] NOT NULL,
	[DatabaseName] [varchar](256) NOT NULL,
	[DataSizeGB] [decimal](18, 2) NULL,
	[LogSizeGB] [decimal](18, 2) NULL,
	[TotalSizeGB]  AS (isnull([DataSizeGB],(0))+isnull([LogSizeGB],(0))) PERSISTED,
	[CreatedDate] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_SQLDatabaseDailySnapshot] PRIMARY KEY CLUSTERED 
(
	[SnapshotDate] ASC,
	[SQLInstanceID] ASC,
	[DatabaseName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [inventory].[SQLDatabaseMonthlyMax]    Script Date: 4/2/2026 4:32:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [inventory].[SQLDatabaseMonthlyMax](
	[YearMonth] [char](7) NOT NULL,
	[SQLInstanceID] [int] NOT NULL,
	[DatabaseName] [varchar](256) NOT NULL,
	[MaxDataSizeGB] [decimal](18, 2) NULL,
	[MaxLogSizeGB] [decimal](18, 2) NULL,
	[MaxTotalSizeGB]  AS (isnull([MaxDataSizeGB],(0))+isnull([MaxLogSizeGB],(0))) PERSISTED,
	[CalcDate] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_SQLDatabaseMonthlyMax] PRIMARY KEY CLUSTERED 
(
	[YearMonth] ASC,
	[SQLInstanceID] ASC,
	[DatabaseName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [inventory].[SQLEdition]    Script Date: 4/2/2026 4:32:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [inventory].[SQLEdition](
	[SQLEditionID] [int] IDENTITY(1,1) NOT NULL,
	[SQLEditionName] [varchar](100) NOT NULL,
 CONSTRAINT [PK_SQLEdition] PRIMARY KEY CLUSTERED 
(
	[SQLEditionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [inventory].[SQLInstance]    Script Date: 4/2/2026 4:32:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [inventory].[SQLInstance](
	[SQLInstanceID] [int] IDENTITY(1,1) NOT NULL,
	[ServerID] [int] NOT NULL,
	[InstanceName] [varchar](150) NOT NULL,
	[InstanceTypeID] [int] NOT NULL,
	[CreatedDate] [datetime2](7) NOT NULL,
	[CreatedBy] [varchar](100) NOT NULL,
	[ModifiedDate] [datetime2](7) NULL,
	[ModifiedBy] [varchar](100) NULL,
	[IsActive] [bit] NOT NULL,
	[SQLInstallDate] [date] NULL,
 CONSTRAINT [PK_SQLInstance] PRIMARY KEY CLUSTERED 
(
	[SQLInstanceID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [inventory].[SQLInstanceCollation]    Script Date: 4/2/2026 4:32:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [inventory].[SQLInstanceCollation](
	[InstanceCollationID] [int] IDENTITY(1,1) NOT NULL,
	[InstanceCollationName] [varchar](100) NOT NULL,
 CONSTRAINT [PK_SQLInstanceCollation] PRIMARY KEY CLUSTERED 
(
	[InstanceCollationID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [inventory].[SQLInstanceConfig]    Script Date: 4/2/2026 4:32:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [inventory].[SQLInstanceConfig](
	[SQLInstanceConfigID] [int] IDENTITY(1,1) NOT NULL,
	[SQLInstanceID] [int] NOT NULL,
	[InstanceCollationID] [int] NOT NULL,
	[MinMemoryMB] [int] NULL,
	[MaxMemoryMB] [int] NULL,
	[MaxDOP] [int] NULL,
	[CostThresholdParallelism] [int] NULL,
	[AdhocWorkload] [bit] NULL,
	[LockPageInMemory] [bit] NULL,
	[IFI] [bit] NULL,
	[DatabaseMail] [bit] NULL,
	[FileStream] [bit] NULL,
	[IsCurrent] [bit] NOT NULL,
	[EffectiveDate] [date] NOT NULL,
 CONSTRAINT [PK_SQLInstanceConfig] PRIMARY KEY CLUSTERED 
(
	[SQLInstanceConfigID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [inventory].[SQLInstanceLinkedServer]    Script Date: 4/2/2026 4:32:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [inventory].[SQLInstanceLinkedServer](
	[SQLInstanceID] [int] NOT NULL,
	[LinkedServerName] [sysname] NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedDate] [datetime2](7) NOT NULL,
	[CreatedBy] [varchar](100) NULL,
	[ModifiedDate] [datetime2](7) NULL,
	[ModifiedBy] [varchar](100) NULL,
 CONSTRAINT [PK_SQLInstanceLinkedServer] PRIMARY KEY CLUSTERED 
(
	[SQLInstanceID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [inventory].[SQLInstanceType]    Script Date: 4/2/2026 4:32:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [inventory].[SQLInstanceType](
	[InstanceTypeID] [int] IDENTITY(1,1) NOT NULL,
	[InstanceTypeName] [varchar](100) NOT NULL,
 CONSTRAINT [PK_SQLInstanceType] PRIMARY KEY CLUSTERED 
(
	[InstanceTypeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [inventory].[SQLInstanceVersion]    Script Date: 4/2/2026 4:32:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [inventory].[SQLInstanceVersion](
	[SQLInstanceVersionID] [int] IDENTITY(1,1) NOT NULL,
	[SQLInstanceID] [int] NOT NULL,
	[SQLVersionID] [int] NOT NULL,
	[SQLEditionID] [int] NOT NULL,
	[ProductBuild] [varchar](50) NOT NULL,
	[ProductLevel] [varchar](50) NOT NULL,
	[IsCurrent] [bit] NOT NULL,
	[EffectiveDate] [date] NOT NULL,
 CONSTRAINT [PK_SQLInstanceVersion] PRIMARY KEY CLUSTERED 
(
	[SQLInstanceVersionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [inventory].[SQLMaintenanceJobRun]    Script Date: 4/2/2026 4:32:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [inventory].[SQLMaintenanceJobRun](
	[SnapshotDate] [date] NOT NULL,
	[SQLInstanceID] [int] NOT NULL,
	[JobName] [varchar](256) NOT NULL,
	[LastRunDateTime] [datetime2](7) NULL,
	[LastRunDurationSec] [int] NULL,
	[LastRunStatus] [varchar](30) NULL,
	[LastRunMessage] [varchar](4000) NULL,
	[CreatedDate] [datetime2](7) NOT NULL,
	[JobCategory] [varchar](128) NULL,
 CONSTRAINT [PK_SQLMaintenanceJobRun] PRIMARY KEY CLUSTERED 
(
	[SnapshotDate] ASC,
	[SQLInstanceID] ASC,
	[JobName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [inventory].[SQLVersion]    Script Date: 4/2/2026 4:32:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [inventory].[SQLVersion](
	[SQLVersionID] [int] IDENTITY(1,1) NOT NULL,
	[SQLVersionName] [varchar](100) NOT NULL,
 CONSTRAINT [PK_SQLVersion] PRIMARY KEY CLUSTERED 
(
	[SQLVersionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [inventory].[Timezone]    Script Date: 4/2/2026 4:32:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [inventory].[Timezone](
	[TimezoneID] [int] IDENTITY(1,1) NOT NULL,
	[Timezone] [varchar](100) NOT NULL,
 CONSTRAINT [PK_Timezone] PRIMARY KEY CLUSTERED 
(
	[TimezoneID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
ALTER TABLE [inventory].[AppUser] ADD  CONSTRAINT [DF_AppUser_IsActive]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [inventory].[AppUser] ADD  CONSTRAINT [DF_AppUser_CreatedDate]  DEFAULT (sysdatetime()) FOR [CreatedDate]
GO
ALTER TABLE [inventory].[AppUser] ADD  CONSTRAINT [DF_AppUser_UserRole_Alter]  DEFAULT ('readonly') FOR [UserRole]
GO
ALTER TABLE [inventory].[ChangeHistory] ADD  DEFAULT (sysdatetime()) FOR [ChangedDate]
GO
ALTER TABLE [inventory].[DatabaseBackup] ADD  CONSTRAINT [DF_DatabaseBackup_IsCopyOnly]  DEFAULT ((0)) FOR [IsCopyOnly]
GO
ALTER TABLE [inventory].[DatabaseBackup] ADD  CONSTRAINT [DF_DatabaseBackup_CollectedDate]  DEFAULT (CONVERT([date],sysdatetime())) FOR [CollectedDate]
GO
ALTER TABLE [inventory].[DatabaseBackup] ADD  CONSTRAINT [DF_DatabaseBackup_CreatedDate]  DEFAULT (sysdatetime()) FOR [CreatedDate]
GO
ALTER TABLE [inventory].[Server] ADD  DEFAULT (sysdatetime()) FOR [CreatedDate]
GO
ALTER TABLE [inventory].[ServerContact] ADD  CONSTRAINT [DF_ServerContact_CreatedDate]  DEFAULT (sysdatetime()) FOR [CreatedDate]
GO
ALTER TABLE [inventory].[ServerHardware] ADD  DEFAULT ((1)) FOR [IsCurrent]
GO
ALTER TABLE [inventory].[ServerHardware] ADD  DEFAULT (sysdatetime()) FOR [CreatedDate]
GO
ALTER TABLE [inventory].[ServerIP] ADD  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [inventory].[ServerStorage] ADD  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [inventory].[ServerStorage] ADD  DEFAULT (getdate()) FOR [CreatedDate]
GO
ALTER TABLE [inventory].[SQLDatabase] ADD  CONSTRAINT [DF_SQLDatabase_CDC]  DEFAULT ((0)) FOR [CDC]
GO
ALTER TABLE [inventory].[SQLDatabase] ADD  CONSTRAINT [DF_SQLDatabase_Encryption]  DEFAULT ((0)) FOR [Encryption]
GO
ALTER TABLE [inventory].[SQLDatabase] ADD  CONSTRAINT [DF_SQLDatabase_QueryStore]  DEFAULT ((0)) FOR [QueryStore]
GO
ALTER TABLE [inventory].[SQLDatabase] ADD  CONSTRAINT [DF_SQLDatabase_AutoUpdateStats]  DEFAULT ((1)) FOR [AutoUpdateStats]
GO
ALTER TABLE [inventory].[SQLDatabase] ADD  CONSTRAINT [DF_SQLDatabase_IsActive]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [inventory].[SQLDatabase] ADD  CONSTRAINT [DF_SQLDatabase_CreatedDate]  DEFAULT (sysdatetime()) FOR [CreatedDate]
GO
ALTER TABLE [inventory].[SQLDatabaseDailySnapshot] ADD  CONSTRAINT [DF_SQLDatabaseDailySnapshot_CreatedDate]  DEFAULT (sysdatetime()) FOR [CreatedDate]
GO
ALTER TABLE [inventory].[SQLDatabaseMonthlyMax] ADD  CONSTRAINT [DF_SQLDatabaseMonthlyMax_CalcDate]  DEFAULT (sysdatetime()) FOR [CalcDate]
GO
ALTER TABLE [inventory].[SQLInstance] ADD  DEFAULT (sysdatetime()) FOR [CreatedDate]
GO
ALTER TABLE [inventory].[SQLInstance] ADD  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [inventory].[SQLInstanceConfig] ADD  DEFAULT ((1)) FOR [IsCurrent]
GO
ALTER TABLE [inventory].[SQLInstanceLinkedServer] ADD  CONSTRAINT [DF_SQLInstanceLinkedServer_IsActive]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [inventory].[SQLInstanceLinkedServer] ADD  CONSTRAINT [DF_SQLInstanceLinkedServer_CreatedDate]  DEFAULT (sysdatetime()) FOR [CreatedDate]
GO
ALTER TABLE [inventory].[SQLInstanceVersion] ADD  DEFAULT ((1)) FOR [IsCurrent]
GO
ALTER TABLE [inventory].[SQLMaintenanceJobRun] ADD  CONSTRAINT [DF_SQLMaintenanceJobRun_SnapshotDate]  DEFAULT (CONVERT([date],sysdatetime())) FOR [SnapshotDate]
GO
ALTER TABLE [inventory].[SQLMaintenanceJobRun] ADD  CONSTRAINT [DF_SQLMaintenanceJobRun_CreatedDate]  DEFAULT (sysdatetime()) FOR [CreatedDate]
GO
ALTER TABLE [inventory].[BusinessUnitContact]  WITH CHECK ADD  CONSTRAINT [FK_BUC_BU] FOREIGN KEY([BUID])
REFERENCES [inventory].[BusinessUnit] ([BUID])
GO
ALTER TABLE [inventory].[BusinessUnitContact] CHECK CONSTRAINT [FK_BUC_BU]
GO
ALTER TABLE [inventory].[BusinessUnitContact]  WITH CHECK ADD  CONSTRAINT [FK_BUC_Category] FOREIGN KEY([ContactCategoryID])
REFERENCES [inventory].[ContactCategory] ([ContactCategoryID])
GO
ALTER TABLE [inventory].[BusinessUnitContact] CHECK CONSTRAINT [FK_BUC_Category]
GO
ALTER TABLE [inventory].[BusinessUnitContact]  WITH CHECK ADD  CONSTRAINT [FK_BUC_Contact] FOREIGN KEY([ContactID])
REFERENCES [inventory].[Contact] ([ContactID])
GO
ALTER TABLE [inventory].[BusinessUnitContact] CHECK CONSTRAINT [FK_BUC_Contact]
GO
ALTER TABLE [inventory].[DatabaseBackup]  WITH CHECK ADD  CONSTRAINT [FK_DatabaseBackup_SQLInstance] FOREIGN KEY([SQLInstanceID])
REFERENCES [inventory].[SQLInstance] ([SQLInstanceID])
GO
ALTER TABLE [inventory].[DatabaseBackup] CHECK CONSTRAINT [FK_DatabaseBackup_SQLInstance]
GO
ALTER TABLE [inventory].[Server]  WITH CHECK ADD  CONSTRAINT [FK_Server_BU] FOREIGN KEY([BUID])
REFERENCES [inventory].[BusinessUnit] ([BUID])
GO
ALTER TABLE [inventory].[Server] CHECK CONSTRAINT [FK_Server_BU]
GO
ALTER TABLE [inventory].[Server]  WITH CHECK ADD  CONSTRAINT [FK_Server_Category] FOREIGN KEY([CategoryID])
REFERENCES [inventory].[ServerCategory] ([CategoryID])
GO
ALTER TABLE [inventory].[Server] CHECK CONSTRAINT [FK_Server_Category]
GO
ALTER TABLE [inventory].[Server]  WITH CHECK ADD  CONSTRAINT [FK_Server_Env] FOREIGN KEY([EnvID])
REFERENCES [inventory].[Environment] ([EnvID])
GO
ALTER TABLE [inventory].[Server] CHECK CONSTRAINT [FK_Server_Env]
GO
ALTER TABLE [inventory].[Server]  WITH CHECK ADD  CONSTRAINT [FK_Server_Region] FOREIGN KEY([RegionID])
REFERENCES [inventory].[Region] ([RegionID])
GO
ALTER TABLE [inventory].[Server] CHECK CONSTRAINT [FK_Server_Region]
GO
ALTER TABLE [inventory].[Server]  WITH CHECK ADD  CONSTRAINT [FK_Server_Status] FOREIGN KEY([StatusID])
REFERENCES [inventory].[ServerStatus] ([StatusID])
GO
ALTER TABLE [inventory].[Server] CHECK CONSTRAINT [FK_Server_Status]
GO
ALTER TABLE [inventory].[ServerContact]  WITH CHECK ADD  CONSTRAINT [FK_ServerContact_Category] FOREIGN KEY([ContactCategoryID])
REFERENCES [inventory].[ContactCategory] ([ContactCategoryID])
GO
ALTER TABLE [inventory].[ServerContact] CHECK CONSTRAINT [FK_ServerContact_Category]
GO
ALTER TABLE [inventory].[ServerContact]  WITH CHECK ADD  CONSTRAINT [FK_ServerContact_Contact] FOREIGN KEY([ContactID])
REFERENCES [inventory].[Contact] ([ContactID])
GO
ALTER TABLE [inventory].[ServerContact] CHECK CONSTRAINT [FK_ServerContact_Contact]
GO
ALTER TABLE [inventory].[ServerContact]  WITH CHECK ADD  CONSTRAINT [FK_ServerContact_Server] FOREIGN KEY([ServerID])
REFERENCES [inventory].[Server] ([ServerID])
GO
ALTER TABLE [inventory].[ServerContact] CHECK CONSTRAINT [FK_ServerContact_Server]
GO
ALTER TABLE [inventory].[ServerHardware]  WITH CHECK ADD  CONSTRAINT [FK_HW_Domain] FOREIGN KEY([DomainID])
REFERENCES [inventory].[Domain] ([DomainID])
GO
ALTER TABLE [inventory].[ServerHardware] CHECK CONSTRAINT [FK_HW_Domain]
GO
ALTER TABLE [inventory].[ServerHardware]  WITH CHECK ADD  CONSTRAINT [FK_HW_OS] FOREIGN KEY([OperatingSystemID])
REFERENCES [inventory].[OSType] ([OSID])
GO
ALTER TABLE [inventory].[ServerHardware] CHECK CONSTRAINT [FK_HW_OS]
GO
ALTER TABLE [inventory].[ServerHardware]  WITH CHECK ADD  CONSTRAINT [FK_HW_Platform] FOREIGN KEY([PlatformID])
REFERENCES [inventory].[Platform] ([PlatformID])
GO
ALTER TABLE [inventory].[ServerHardware] CHECK CONSTRAINT [FK_HW_Platform]
GO
ALTER TABLE [inventory].[ServerHardware]  WITH CHECK ADD  CONSTRAINT [FK_HW_Server] FOREIGN KEY([ServerID])
REFERENCES [inventory].[Server] ([ServerID])
GO
ALTER TABLE [inventory].[ServerHardware] CHECK CONSTRAINT [FK_HW_Server]
GO
ALTER TABLE [inventory].[ServerHardware]  WITH CHECK ADD  CONSTRAINT [FK_HW_ServerType] FOREIGN KEY([ServerTypeID])
REFERENCES [inventory].[ServerType] ([ServerTypeID])
GO
ALTER TABLE [inventory].[ServerHardware] CHECK CONSTRAINT [FK_HW_ServerType]
GO
ALTER TABLE [inventory].[ServerHardware]  WITH CHECK ADD  CONSTRAINT [FK_HW_Timezone] FOREIGN KEY([TimezoneID])
REFERENCES [inventory].[Timezone] ([TimezoneID])
GO
ALTER TABLE [inventory].[ServerHardware] CHECK CONSTRAINT [FK_HW_Timezone]
GO
ALTER TABLE [inventory].[ServerIP]  WITH CHECK ADD  CONSTRAINT [FK_ServerIP_Server] FOREIGN KEY([ServerID])
REFERENCES [inventory].[Server] ([ServerID])
GO
ALTER TABLE [inventory].[ServerIP] CHECK CONSTRAINT [FK_ServerIP_Server]
GO
ALTER TABLE [inventory].[ServerIP]  WITH CHECK ADD  CONSTRAINT [FK_ServerIP_Type] FOREIGN KEY([IPAddressTypeID])
REFERENCES [inventory].[IPAddressType] ([IPAddressTypeID])
GO
ALTER TABLE [inventory].[ServerIP] CHECK CONSTRAINT [FK_ServerIP_Type]
GO
ALTER TABLE [inventory].[ServerStorage]  WITH CHECK ADD  CONSTRAINT [FK_Storage_Server] FOREIGN KEY([ServerID])
REFERENCES [inventory].[Server] ([ServerID])
GO
ALTER TABLE [inventory].[ServerStorage] CHECK CONSTRAINT [FK_Storage_Server]
GO
ALTER TABLE [inventory].[SQLDatabase]  WITH CHECK ADD  CONSTRAINT [FK_SQLDatabase_SQLInstance] FOREIGN KEY([SQLInstanceID])
REFERENCES [inventory].[SQLInstance] ([SQLInstanceID])
GO
ALTER TABLE [inventory].[SQLDatabase] CHECK CONSTRAINT [FK_SQLDatabase_SQLInstance]
GO
ALTER TABLE [inventory].[SQLDatabaseDailySnapshot]  WITH CHECK ADD  CONSTRAINT [FK_SQLDatabaseDailySnapshot_SQLInstance] FOREIGN KEY([SQLInstanceID])
REFERENCES [inventory].[SQLInstance] ([SQLInstanceID])
GO
ALTER TABLE [inventory].[SQLDatabaseDailySnapshot] CHECK CONSTRAINT [FK_SQLDatabaseDailySnapshot_SQLInstance]
GO
ALTER TABLE [inventory].[SQLDatabaseMonthlyMax]  WITH CHECK ADD  CONSTRAINT [FK_SQLDatabaseMonthlyMax_SQLInstance] FOREIGN KEY([SQLInstanceID])
REFERENCES [inventory].[SQLInstance] ([SQLInstanceID])
GO
ALTER TABLE [inventory].[SQLDatabaseMonthlyMax] CHECK CONSTRAINT [FK_SQLDatabaseMonthlyMax_SQLInstance]
GO
ALTER TABLE [inventory].[SQLInstance]  WITH CHECK ADD  CONSTRAINT [FK_SQLInstance_Server] FOREIGN KEY([ServerID])
REFERENCES [inventory].[Server] ([ServerID])
GO
ALTER TABLE [inventory].[SQLInstance] CHECK CONSTRAINT [FK_SQLInstance_Server]
GO
ALTER TABLE [inventory].[SQLInstance]  WITH CHECK ADD  CONSTRAINT [FK_SQLInstance_Type] FOREIGN KEY([InstanceTypeID])
REFERENCES [inventory].[SQLInstanceType] ([InstanceTypeID])
GO
ALTER TABLE [inventory].[SQLInstance] CHECK CONSTRAINT [FK_SQLInstance_Type]
GO
ALTER TABLE [inventory].[SQLInstanceConfig]  WITH CHECK ADD  CONSTRAINT [FK_InstanceConfig_Collation] FOREIGN KEY([InstanceCollationID])
REFERENCES [inventory].[SQLInstanceCollation] ([InstanceCollationID])
GO
ALTER TABLE [inventory].[SQLInstanceConfig] CHECK CONSTRAINT [FK_InstanceConfig_Collation]
GO
ALTER TABLE [inventory].[SQLInstanceConfig]  WITH CHECK ADD  CONSTRAINT [FK_InstanceConfig_Instance] FOREIGN KEY([SQLInstanceID])
REFERENCES [inventory].[SQLInstance] ([SQLInstanceID])
GO
ALTER TABLE [inventory].[SQLInstanceConfig] CHECK CONSTRAINT [FK_InstanceConfig_Instance]
GO
ALTER TABLE [inventory].[SQLInstanceLinkedServer]  WITH CHECK ADD  CONSTRAINT [FK_SQLInstanceLinkedServer_SQLInstance] FOREIGN KEY([SQLInstanceID])
REFERENCES [inventory].[SQLInstance] ([SQLInstanceID])
GO
ALTER TABLE [inventory].[SQLInstanceLinkedServer] CHECK CONSTRAINT [FK_SQLInstanceLinkedServer_SQLInstance]
GO
ALTER TABLE [inventory].[SQLInstanceVersion]  WITH CHECK ADD  CONSTRAINT [FK_InstanceVersion_Edition] FOREIGN KEY([SQLEditionID])
REFERENCES [inventory].[SQLEdition] ([SQLEditionID])
GO
ALTER TABLE [inventory].[SQLInstanceVersion] CHECK CONSTRAINT [FK_InstanceVersion_Edition]
GO
ALTER TABLE [inventory].[SQLInstanceVersion]  WITH CHECK ADD  CONSTRAINT [FK_InstanceVersion_Instance] FOREIGN KEY([SQLInstanceID])
REFERENCES [inventory].[SQLInstance] ([SQLInstanceID])
GO
ALTER TABLE [inventory].[SQLInstanceVersion] CHECK CONSTRAINT [FK_InstanceVersion_Instance]
GO
ALTER TABLE [inventory].[SQLInstanceVersion]  WITH CHECK ADD  CONSTRAINT [FK_InstanceVersion_Version] FOREIGN KEY([SQLVersionID])
REFERENCES [inventory].[SQLVersion] ([SQLVersionID])
GO
ALTER TABLE [inventory].[SQLInstanceVersion] CHECK CONSTRAINT [FK_InstanceVersion_Version]
GO
ALTER TABLE [inventory].[SQLMaintenanceJobRun]  WITH CHECK ADD  CONSTRAINT [FK_SQLMaintenanceJobRun_SQLInstance] FOREIGN KEY([SQLInstanceID])
REFERENCES [inventory].[SQLInstance] ([SQLInstanceID])
GO
ALTER TABLE [inventory].[SQLMaintenanceJobRun] CHECK CONSTRAINT [FK_SQLMaintenanceJobRun_SQLInstance]
GO
