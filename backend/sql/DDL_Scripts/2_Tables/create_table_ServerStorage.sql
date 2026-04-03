/****** Object:  Table [inventory].[ServerStorage]    Script Date: 03-04-2026 15:48:46 ******/
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
CREATE TABLE [inventory].[ServerStorage](
	[StorageID] [int] IDENTITY(1,1) NOT NULL,
	[ServerID] [int] NOT NULL,
	[DriveLetter] [char](1) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[VolumeLabel] [varchar](100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[TotalSizeGB] [decimal](18, 2) NOT NULL,
	[FreeSpaceGB] [decimal](18, 2) NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedDate] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_ServerStorage] PRIMARY KEY CLUSTERED 
(
	[StorageID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

/****** Object:  Index [IX_Storage_ServerID]    Script Date: 03-04-2026 15:48:46 ******/
CREATE NONCLUSTERED INDEX [IX_Storage_ServerID] ON [inventory].[ServerStorage]
(
	[ServerID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
SET ANSI_PADDING ON

/****** Object:  Index [UX_Server_Drive]    Script Date: 03-04-2026 15:48:46 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_Server_Drive] ON [inventory].[ServerStorage]
(
	[ServerID] ASC,
	[DriveLetter] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
ALTER TABLE [inventory].[ServerStorage] ADD  DEFAULT ((1)) FOR [IsActive]
ALTER TABLE [inventory].[ServerStorage] ADD  DEFAULT (getdate()) FOR [CreatedDate]
ALTER TABLE [inventory].[ServerStorage]  WITH CHECK ADD  CONSTRAINT [FK_Storage_Server] FOREIGN KEY([ServerID])
REFERENCES [inventory].[Server] ([ServerID])
ALTER TABLE [inventory].[ServerStorage] CHECK CONSTRAINT [FK_Storage_Server]
