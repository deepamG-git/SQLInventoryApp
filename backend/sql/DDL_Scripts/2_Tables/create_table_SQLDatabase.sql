/****** Object:  Table [inventory].[SQLDatabase]    Script Date: 03-04-2026 15:48:46 ******/
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
CREATE TABLE [inventory].[SQLDatabase](
	[SQLDatabaseID] [int] IDENTITY(1,1) NOT NULL,
	[SQLInstanceID] [int] NOT NULL,
	[DatabaseName] [varchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Owner] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[SizeGB] [decimal](18, 2) NULL,
	[CreatedOn] [datetime2](7) NULL,
	[RecoveryModel] [varchar](30) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[DatabaseCollation] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[CDC] [bit] NOT NULL,
	[CompatibilityLevel] [int] NULL,
	[Encryption] [bit] NOT NULL,
	[QueryStore] [bit] NOT NULL,
	[AutoUpdateStats] [bit] NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedDate] [datetime2](7) NOT NULL,
	[CreatedBy] [varchar](100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[ModifiedDate] [datetime2](7) NULL,
	[ModifiedBy] [varchar](100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[DataSizeGB] [decimal](18, 2) NULL,
	[LogSizeGB] [decimal](18, 2) NULL,
	[TotalSizeGB]  AS (case when [DataSizeGB] IS NULL AND [LogSizeGB] IS NULL then isnull([SizeGB],(0)) else isnull([DataSizeGB],(0))+isnull([LogSizeGB],(0)) end) PERSISTED,
 CONSTRAINT [PK_SQLDatabase] PRIMARY KEY CLUSTERED 
(
	[SQLDatabaseID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

/****** Object:  Index [IX_SQLDatabase_InstanceID]    Script Date: 03-04-2026 15:48:46 ******/
CREATE NONCLUSTERED INDEX [IX_SQLDatabase_InstanceID] ON [inventory].[SQLDatabase]
(
	[SQLInstanceID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
SET ANSI_PADDING ON

/****** Object:  Index [UX_SQLDatabase_Instance_DbName]    Script Date: 03-04-2026 15:48:46 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_SQLDatabase_Instance_DbName] ON [inventory].[SQLDatabase]
(
	[SQLInstanceID] ASC,
	[DatabaseName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
ALTER TABLE [inventory].[SQLDatabase] ADD  CONSTRAINT [DF_SQLDatabase_CDC]  DEFAULT ((0)) FOR [CDC]
ALTER TABLE [inventory].[SQLDatabase] ADD  CONSTRAINT [DF_SQLDatabase_Encryption]  DEFAULT ((0)) FOR [Encryption]
ALTER TABLE [inventory].[SQLDatabase] ADD  CONSTRAINT [DF_SQLDatabase_QueryStore]  DEFAULT ((0)) FOR [QueryStore]
ALTER TABLE [inventory].[SQLDatabase] ADD  CONSTRAINT [DF_SQLDatabase_AutoUpdateStats]  DEFAULT ((1)) FOR [AutoUpdateStats]
ALTER TABLE [inventory].[SQLDatabase] ADD  CONSTRAINT [DF_SQLDatabase_IsActive]  DEFAULT ((1)) FOR [IsActive]
ALTER TABLE [inventory].[SQLDatabase] ADD  CONSTRAINT [DF_SQLDatabase_CreatedDate]  DEFAULT (sysdatetime()) FOR [CreatedDate]
ALTER TABLE [inventory].[SQLDatabase]  WITH CHECK ADD  CONSTRAINT [FK_SQLDatabase_SQLInstance] FOREIGN KEY([SQLInstanceID])
REFERENCES [inventory].[SQLInstance] ([SQLInstanceID])
ALTER TABLE [inventory].[SQLDatabase] CHECK CONSTRAINT [FK_SQLDatabase_SQLInstance]
