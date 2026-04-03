/****** Object:  Table [inventory].[SQLInstanceConfig]    Script Date: 03-04-2026 15:48:47 ******/
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
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

/****** Object:  Index [UX_InstanceConfig_Current]    Script Date: 03-04-2026 15:48:47 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_InstanceConfig_Current] ON [inventory].[SQLInstanceConfig]
(
	[SQLInstanceID] ASC
)
WHERE ([IsCurrent]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
ALTER TABLE [inventory].[SQLInstanceConfig] ADD  DEFAULT ((1)) FOR [IsCurrent]
ALTER TABLE [inventory].[SQLInstanceConfig]  WITH CHECK ADD  CONSTRAINT [FK_InstanceConfig_Collation] FOREIGN KEY([InstanceCollationID])
REFERENCES [inventory].[SQLInstanceCollation] ([InstanceCollationID])
ALTER TABLE [inventory].[SQLInstanceConfig] CHECK CONSTRAINT [FK_InstanceConfig_Collation]
ALTER TABLE [inventory].[SQLInstanceConfig]  WITH CHECK ADD  CONSTRAINT [FK_InstanceConfig_Instance] FOREIGN KEY([SQLInstanceID])
REFERENCES [inventory].[SQLInstance] ([SQLInstanceID])
ALTER TABLE [inventory].[SQLInstanceConfig] CHECK CONSTRAINT [FK_InstanceConfig_Instance]
