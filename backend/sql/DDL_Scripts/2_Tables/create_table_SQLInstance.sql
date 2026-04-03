/****** Object:  Table [inventory].[SQLInstance]    Script Date: 03-04-2026 15:48:47 ******/
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
CREATE TABLE [inventory].[SQLInstance](
	[SQLInstanceID] [int] IDENTITY(1,1) NOT NULL,
	[ServerID] [int] NOT NULL,
	[InstanceName] [varchar](150) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[InstanceTypeID] [int] NOT NULL,
	[CreatedDate] [datetime2](7) NOT NULL,
	[CreatedBy] [varchar](100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[ModifiedDate] [datetime2](7) NULL,
	[ModifiedBy] [varchar](100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[IsActive] [bit] NOT NULL,
	[SQLInstallDate] [date] NULL,
 CONSTRAINT [PK_SQLInstance] PRIMARY KEY CLUSTERED 
(
	[SQLInstanceID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

/****** Object:  Index [IX_SQLInstance_ServerID]    Script Date: 03-04-2026 15:48:47 ******/
CREATE NONCLUSTERED INDEX [IX_SQLInstance_ServerID] ON [inventory].[SQLInstance]
(
	[ServerID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
SET ANSI_PADDING ON

/****** Object:  Index [UX_Instance_Server_InstanceName]    Script Date: 03-04-2026 15:48:47 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_Instance_Server_InstanceName] ON [inventory].[SQLInstance]
(
	[ServerID] ASC,
	[InstanceName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
ALTER TABLE [inventory].[SQLInstance] ADD  DEFAULT (sysdatetime()) FOR [CreatedDate]
ALTER TABLE [inventory].[SQLInstance] ADD  DEFAULT ((1)) FOR [IsActive]
ALTER TABLE [inventory].[SQLInstance]  WITH CHECK ADD  CONSTRAINT [FK_SQLInstance_Server] FOREIGN KEY([ServerID])
REFERENCES [inventory].[Server] ([ServerID])
ALTER TABLE [inventory].[SQLInstance] CHECK CONSTRAINT [FK_SQLInstance_Server]
ALTER TABLE [inventory].[SQLInstance]  WITH CHECK ADD  CONSTRAINT [FK_SQLInstance_Type] FOREIGN KEY([InstanceTypeID])
REFERENCES [inventory].[SQLInstanceType] ([InstanceTypeID])
ALTER TABLE [inventory].[SQLInstance] CHECK CONSTRAINT [FK_SQLInstance_Type]
