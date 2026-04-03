/****** Object:  Table [inventory].[DatabaseBackup]    Script Date: 03-04-2026 15:48:44 ******/
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
CREATE TABLE [inventory].[DatabaseBackup](
	[DatabaseBackupID] [bigint] IDENTITY(1,1) NOT NULL,
	[SQLInstanceID] [int] NOT NULL,
	[DatabaseName] [varchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[BackupType] [char](1) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
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

/****** Object:  Index [IX_DatabaseBackup_Instance_Finish]    Script Date: 03-04-2026 15:48:44 ******/
CREATE NONCLUSTERED INDEX [IX_DatabaseBackup_Instance_Finish] ON [inventory].[DatabaseBackup]
(
	[SQLInstanceID] ASC,
	[BackupFinishDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
/****** Object:  Index [UX_DatabaseBackup_Instance_BackupSet]    Script Date: 03-04-2026 15:48:44 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_DatabaseBackup_Instance_BackupSet] ON [inventory].[DatabaseBackup]
(
	[SQLInstanceID] ASC,
	[BackupSetID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
ALTER TABLE [inventory].[DatabaseBackup] ADD  CONSTRAINT [DF_DatabaseBackup_IsCopyOnly]  DEFAULT ((0)) FOR [IsCopyOnly]
ALTER TABLE [inventory].[DatabaseBackup] ADD  CONSTRAINT [DF_DatabaseBackup_CollectedDate]  DEFAULT (CONVERT([date],sysdatetime())) FOR [CollectedDate]
ALTER TABLE [inventory].[DatabaseBackup] ADD  CONSTRAINT [DF_DatabaseBackup_CreatedDate]  DEFAULT (sysdatetime()) FOR [CreatedDate]
ALTER TABLE [inventory].[DatabaseBackup]  WITH CHECK ADD  CONSTRAINT [FK_DatabaseBackup_SQLInstance] FOREIGN KEY([SQLInstanceID])
REFERENCES [inventory].[SQLInstance] ([SQLInstanceID])
ALTER TABLE [inventory].[DatabaseBackup] CHECK CONSTRAINT [FK_DatabaseBackup_SQLInstance]
