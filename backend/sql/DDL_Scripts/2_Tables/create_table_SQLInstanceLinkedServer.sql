/****** Object:  Table [inventory].[SQLInstanceLinkedServer]    Script Date: 03-04-2026 15:48:47 ******/
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
CREATE TABLE [inventory].[SQLInstanceLinkedServer](
	[SQLInstanceID] [int] NOT NULL,
	[LinkedServerName] [sysname] COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedDate] [datetime2](7) NOT NULL,
	[CreatedBy] [varchar](100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[ModifiedDate] [datetime2](7) NULL,
	[ModifiedBy] [varchar](100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_SQLInstanceLinkedServer] PRIMARY KEY CLUSTERED 
(
	[SQLInstanceID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

SET ANSI_PADDING ON

/****** Object:  Index [UX_SQLInstanceLinkedServer_Name]    Script Date: 03-04-2026 15:48:47 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_SQLInstanceLinkedServer_Name] ON [inventory].[SQLInstanceLinkedServer]
(
	[LinkedServerName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
ALTER TABLE [inventory].[SQLInstanceLinkedServer] ADD  CONSTRAINT [DF_SQLInstanceLinkedServer_IsActive]  DEFAULT ((1)) FOR [IsActive]
ALTER TABLE [inventory].[SQLInstanceLinkedServer] ADD  CONSTRAINT [DF_SQLInstanceLinkedServer_CreatedDate]  DEFAULT (sysdatetime()) FOR [CreatedDate]
ALTER TABLE [inventory].[SQLInstanceLinkedServer]  WITH CHECK ADD  CONSTRAINT [FK_SQLInstanceLinkedServer_SQLInstance] FOREIGN KEY([SQLInstanceID])
REFERENCES [inventory].[SQLInstance] ([SQLInstanceID])
ALTER TABLE [inventory].[SQLInstanceLinkedServer] CHECK CONSTRAINT [FK_SQLInstanceLinkedServer_SQLInstance]
