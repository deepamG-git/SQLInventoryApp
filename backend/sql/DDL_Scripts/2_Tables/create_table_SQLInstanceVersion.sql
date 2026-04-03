/****** Object:  Table [inventory].[SQLInstanceVersion]    Script Date: 03-04-2026 15:48:47 ******/
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
CREATE TABLE [inventory].[SQLInstanceVersion](
	[SQLInstanceVersionID] [int] IDENTITY(1,1) NOT NULL,
	[SQLInstanceID] [int] NOT NULL,
	[SQLVersionID] [int] NOT NULL,
	[SQLEditionID] [int] NOT NULL,
	[ProductBuild] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[ProductLevel] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[IsCurrent] [bit] NOT NULL,
	[EffectiveDate] [date] NOT NULL,
 CONSTRAINT [PK_SQLInstanceVersion] PRIMARY KEY CLUSTERED 
(
	[SQLInstanceVersionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

/****** Object:  Index [IX_InstanceVersion_InstanceID]    Script Date: 03-04-2026 15:48:47 ******/
CREATE NONCLUSTERED INDEX [IX_InstanceVersion_InstanceID] ON [inventory].[SQLInstanceVersion]
(
	[SQLInstanceID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
/****** Object:  Index [UX_InstanceVersion_Current]    Script Date: 03-04-2026 15:48:47 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_InstanceVersion_Current] ON [inventory].[SQLInstanceVersion]
(
	[SQLInstanceID] ASC
)
WHERE ([IsCurrent]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
ALTER TABLE [inventory].[SQLInstanceVersion] ADD  DEFAULT ((1)) FOR [IsCurrent]
ALTER TABLE [inventory].[SQLInstanceVersion]  WITH CHECK ADD  CONSTRAINT [FK_InstanceVersion_Edition] FOREIGN KEY([SQLEditionID])
REFERENCES [inventory].[SQLEdition] ([SQLEditionID])
ALTER TABLE [inventory].[SQLInstanceVersion] CHECK CONSTRAINT [FK_InstanceVersion_Edition]
ALTER TABLE [inventory].[SQLInstanceVersion]  WITH CHECK ADD  CONSTRAINT [FK_InstanceVersion_Instance] FOREIGN KEY([SQLInstanceID])
REFERENCES [inventory].[SQLInstance] ([SQLInstanceID])
ALTER TABLE [inventory].[SQLInstanceVersion] CHECK CONSTRAINT [FK_InstanceVersion_Instance]
ALTER TABLE [inventory].[SQLInstanceVersion]  WITH CHECK ADD  CONSTRAINT [FK_InstanceVersion_Version] FOREIGN KEY([SQLVersionID])
REFERENCES [inventory].[SQLVersion] ([SQLVersionID])
ALTER TABLE [inventory].[SQLInstanceVersion] CHECK CONSTRAINT [FK_InstanceVersion_Version]
