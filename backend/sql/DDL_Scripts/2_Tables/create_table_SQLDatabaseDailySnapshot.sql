/****** Object:  Table [inventory].[SQLDatabaseDailySnapshot]    Script Date: 03-04-2026 15:48:46 ******/
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
CREATE TABLE [inventory].[SQLDatabaseDailySnapshot](
	[SnapshotDate] [date] NOT NULL,
	[SQLInstanceID] [int] NOT NULL,
	[DatabaseName] [varchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
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

/****** Object:  Index [IX_SQLDatabaseDailySnapshot_Instance]    Script Date: 03-04-2026 15:48:46 ******/
CREATE NONCLUSTERED INDEX [IX_SQLDatabaseDailySnapshot_Instance] ON [inventory].[SQLDatabaseDailySnapshot]
(
	[SQLInstanceID] ASC,
	[SnapshotDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
ALTER TABLE [inventory].[SQLDatabaseDailySnapshot] ADD  CONSTRAINT [DF_SQLDatabaseDailySnapshot_CreatedDate]  DEFAULT (sysdatetime()) FOR [CreatedDate]
ALTER TABLE [inventory].[SQLDatabaseDailySnapshot]  WITH CHECK ADD  CONSTRAINT [FK_SQLDatabaseDailySnapshot_SQLInstance] FOREIGN KEY([SQLInstanceID])
REFERENCES [inventory].[SQLInstance] ([SQLInstanceID])
ALTER TABLE [inventory].[SQLDatabaseDailySnapshot] CHECK CONSTRAINT [FK_SQLDatabaseDailySnapshot_SQLInstance]
