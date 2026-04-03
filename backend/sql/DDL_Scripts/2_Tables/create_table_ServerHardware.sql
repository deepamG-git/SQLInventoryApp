/****** Object:  Table [inventory].[ServerHardware]    Script Date: 03-04-2026 15:48:45 ******/
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
CREATE TABLE [inventory].[ServerHardware](
	[ServerHardwareID] [int] IDENTITY(1,1) NOT NULL,
	[ServerID] [int] NOT NULL,
	[DomainID] [int] NOT NULL,
	[OperatingSystemID] [int] NOT NULL,
	[MemoryGB] [int] NOT NULL,
	[CPUCores] [int] NOT NULL,
	[ProcessorModel] [varchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[ServerTypeID] [int] NOT NULL,
	[PlatformID] [int] NOT NULL,
	[TimezoneID] [int] NOT NULL,
	[OSInstallDate] [date] NULL,
	[IsCurrent] [bit] NOT NULL,
	[EffectiveDate] [date] NOT NULL,
	[CreatedDate] [datetime2](7) NOT NULL,
	[CreatedBy] [varchar](100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[ModifiedDate] [datetime2](7) NULL,
	[ModifiedBy] [varchar](100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_ServerHardware] PRIMARY KEY CLUSTERED 
(
	[ServerHardwareID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

/****** Object:  Index [IX_HW_Platform]    Script Date: 03-04-2026 15:48:45 ******/
CREATE NONCLUSTERED INDEX [IX_HW_Platform] ON [inventory].[ServerHardware]
(
	[PlatformID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
/****** Object:  Index [IX_HW_ServerID]    Script Date: 03-04-2026 15:48:45 ******/
CREATE NONCLUSTERED INDEX [IX_HW_ServerID] ON [inventory].[ServerHardware]
(
	[ServerID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
/****** Object:  Index [UX_HW_Current]    Script Date: 03-04-2026 15:48:45 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_HW_Current] ON [inventory].[ServerHardware]
(
	[ServerID] ASC
)
WHERE ([IsCurrent]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
ALTER TABLE [inventory].[ServerHardware] ADD  DEFAULT ((1)) FOR [IsCurrent]
ALTER TABLE [inventory].[ServerHardware] ADD  DEFAULT (sysdatetime()) FOR [CreatedDate]
ALTER TABLE [inventory].[ServerHardware]  WITH CHECK ADD  CONSTRAINT [FK_HW_Domain] FOREIGN KEY([DomainID])
REFERENCES [inventory].[Domain] ([DomainID])
ALTER TABLE [inventory].[ServerHardware] CHECK CONSTRAINT [FK_HW_Domain]
ALTER TABLE [inventory].[ServerHardware]  WITH CHECK ADD  CONSTRAINT [FK_HW_OS] FOREIGN KEY([OperatingSystemID])
REFERENCES [inventory].[OSType] ([OSID])
ALTER TABLE [inventory].[ServerHardware] CHECK CONSTRAINT [FK_HW_OS]
ALTER TABLE [inventory].[ServerHardware]  WITH CHECK ADD  CONSTRAINT [FK_HW_Platform] FOREIGN KEY([PlatformID])
REFERENCES [inventory].[Platform] ([PlatformID])
ALTER TABLE [inventory].[ServerHardware] CHECK CONSTRAINT [FK_HW_Platform]
ALTER TABLE [inventory].[ServerHardware]  WITH CHECK ADD  CONSTRAINT [FK_HW_Server] FOREIGN KEY([ServerID])
REFERENCES [inventory].[Server] ([ServerID])
ALTER TABLE [inventory].[ServerHardware] CHECK CONSTRAINT [FK_HW_Server]
ALTER TABLE [inventory].[ServerHardware]  WITH CHECK ADD  CONSTRAINT [FK_HW_ServerType] FOREIGN KEY([ServerTypeID])
REFERENCES [inventory].[ServerType] ([ServerTypeID])
ALTER TABLE [inventory].[ServerHardware] CHECK CONSTRAINT [FK_HW_ServerType]
ALTER TABLE [inventory].[ServerHardware]  WITH CHECK ADD  CONSTRAINT [FK_HW_Timezone] FOREIGN KEY([TimezoneID])
REFERENCES [inventory].[Timezone] ([TimezoneID])
ALTER TABLE [inventory].[ServerHardware] CHECK CONSTRAINT [FK_HW_Timezone]
