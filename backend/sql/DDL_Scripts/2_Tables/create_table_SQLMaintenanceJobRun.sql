/****** Object:  Table [inventory].[SQLMaintenanceJobRun]    Script Date: 03-04-2026 15:48:47 ******/
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
CREATE TABLE [inventory].[SQLMaintenanceJobRun](
	[SnapshotDate] [date] NOT NULL,
	[SQLInstanceID] [int] NOT NULL,
	[JobName] [varchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[LastRunDateTime] [datetime2](7) NULL,
	[LastRunDurationSec] [int] NULL,
	[LastRunStatus] [varchar](30) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[LastRunMessage] [varchar](4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[CreatedDate] [datetime2](7) NOT NULL,
	[JobCategory] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_SQLMaintenanceJobRun] PRIMARY KEY CLUSTERED 
(
	[SnapshotDate] ASC,
	[SQLInstanceID] ASC,
	[JobName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

/****** Object:  Index [IX_SQLMaintenanceJobRun_Instance]    Script Date: 03-04-2026 15:48:47 ******/
CREATE NONCLUSTERED INDEX [IX_SQLMaintenanceJobRun_Instance] ON [inventory].[SQLMaintenanceJobRun]
(
	[SQLInstanceID] ASC,
	[SnapshotDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
ALTER TABLE [inventory].[SQLMaintenanceJobRun] ADD  CONSTRAINT [DF_SQLMaintenanceJobRun_SnapshotDate]  DEFAULT (CONVERT([date],sysdatetime())) FOR [SnapshotDate]
ALTER TABLE [inventory].[SQLMaintenanceJobRun] ADD  CONSTRAINT [DF_SQLMaintenanceJobRun_CreatedDate]  DEFAULT (sysdatetime()) FOR [CreatedDate]
ALTER TABLE [inventory].[SQLMaintenanceJobRun]  WITH CHECK ADD  CONSTRAINT [FK_SQLMaintenanceJobRun_SQLInstance] FOREIGN KEY([SQLInstanceID])
REFERENCES [inventory].[SQLInstance] ([SQLInstanceID])
ALTER TABLE [inventory].[SQLMaintenanceJobRun] CHECK CONSTRAINT [FK_SQLMaintenanceJobRun_SQLInstance]
