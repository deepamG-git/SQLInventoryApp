/****** Object:  Table [inventory].[Server]    Script Date: 03-04-2026 15:48:45 ******/
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
CREATE TABLE [inventory].[Server](
	[ServerID] [int] IDENTITY(1,1) NOT NULL,
	[ServerName] [varchar](150) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Description] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[EnvID] [int] NOT NULL,
	[BUID] [int] NOT NULL,
	[CategoryID] [int] NOT NULL,
	[RegionID] [int] NOT NULL,
	[StatusID] [int] NOT NULL,
	[CreatedDate] [datetime2](7) NOT NULL,
	[CreatedBy] [varchar](100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[ModifiedDate] [datetime2](7) NULL,
	[ModifiedBy] [varchar](100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_Server] PRIMARY KEY CLUSTERED 
(
	[ServerID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

/****** Object:  Index [IX_Server_BU]    Script Date: 03-04-2026 15:48:45 ******/
CREATE NONCLUSTERED INDEX [IX_Server_BU] ON [inventory].[Server]
(
	[BUID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
/****** Object:  Index [IX_Server_Env]    Script Date: 03-04-2026 15:48:45 ******/
CREATE NONCLUSTERED INDEX [IX_Server_Env] ON [inventory].[Server]
(
	[EnvID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
/****** Object:  Index [IX_Server_Status]    Script Date: 03-04-2026 15:48:45 ******/
CREATE NONCLUSTERED INDEX [IX_Server_Status] ON [inventory].[Server]
(
	[StatusID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
SET ANSI_PADDING ON

/****** Object:  Index [UX_Server_Name]    Script Date: 03-04-2026 15:48:45 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_Server_Name] ON [inventory].[Server]
(
	[ServerName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
ALTER TABLE [inventory].[Server] ADD  DEFAULT (sysdatetime()) FOR [CreatedDate]
ALTER TABLE [inventory].[Server]  WITH CHECK ADD  CONSTRAINT [FK_Server_BU] FOREIGN KEY([BUID])
REFERENCES [inventory].[BusinessUnit] ([BUID])
ALTER TABLE [inventory].[Server] CHECK CONSTRAINT [FK_Server_BU]
ALTER TABLE [inventory].[Server]  WITH CHECK ADD  CONSTRAINT [FK_Server_Category] FOREIGN KEY([CategoryID])
REFERENCES [inventory].[ServerCategory] ([CategoryID])
ALTER TABLE [inventory].[Server] CHECK CONSTRAINT [FK_Server_Category]
ALTER TABLE [inventory].[Server]  WITH CHECK ADD  CONSTRAINT [FK_Server_Env] FOREIGN KEY([EnvID])
REFERENCES [inventory].[Environment] ([EnvID])
ALTER TABLE [inventory].[Server] CHECK CONSTRAINT [FK_Server_Env]
ALTER TABLE [inventory].[Server]  WITH CHECK ADD  CONSTRAINT [FK_Server_Region] FOREIGN KEY([RegionID])
REFERENCES [inventory].[Region] ([RegionID])
ALTER TABLE [inventory].[Server] CHECK CONSTRAINT [FK_Server_Region]
ALTER TABLE [inventory].[Server]  WITH CHECK ADD  CONSTRAINT [FK_Server_Status] FOREIGN KEY([StatusID])
REFERENCES [inventory].[ServerStatus] ([StatusID])
ALTER TABLE [inventory].[Server] CHECK CONSTRAINT [FK_Server_Status]
