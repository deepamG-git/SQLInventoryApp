/****** Object:  Table [inventory].[ServerContact]    Script Date: 03-04-2026 15:48:45 ******/
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
CREATE TABLE [inventory].[ServerContact](
	[ServerID] [int] NOT NULL,
	[ContactID] [int] NOT NULL,
	[ContactCategoryID] [int] NOT NULL,
	[CreatedDate] [datetime2](7) NOT NULL,
	[CreatedBy] [varchar](100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_ServerContact] PRIMARY KEY CLUSTERED 
(
	[ServerID] ASC,
	[ContactID] ASC,
	[ContactCategoryID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

/****** Object:  Index [IX_ServerContact_ContactID]    Script Date: 03-04-2026 15:48:45 ******/
CREATE NONCLUSTERED INDEX [IX_ServerContact_ContactID] ON [inventory].[ServerContact]
(
	[ContactID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
/****** Object:  Index [IX_ServerContact_ServerID]    Script Date: 03-04-2026 15:48:45 ******/
CREATE NONCLUSTERED INDEX [IX_ServerContact_ServerID] ON [inventory].[ServerContact]
(
	[ServerID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
ALTER TABLE [inventory].[ServerContact] ADD  CONSTRAINT [DF_ServerContact_CreatedDate]  DEFAULT (sysdatetime()) FOR [CreatedDate]
ALTER TABLE [inventory].[ServerContact]  WITH CHECK ADD  CONSTRAINT [FK_ServerContact_Category] FOREIGN KEY([ContactCategoryID])
REFERENCES [inventory].[ContactCategory] ([ContactCategoryID])
ALTER TABLE [inventory].[ServerContact] CHECK CONSTRAINT [FK_ServerContact_Category]
ALTER TABLE [inventory].[ServerContact]  WITH CHECK ADD  CONSTRAINT [FK_ServerContact_Contact] FOREIGN KEY([ContactID])
REFERENCES [inventory].[Contact] ([ContactID])
ALTER TABLE [inventory].[ServerContact] CHECK CONSTRAINT [FK_ServerContact_Contact]
ALTER TABLE [inventory].[ServerContact]  WITH CHECK ADD  CONSTRAINT [FK_ServerContact_Server] FOREIGN KEY([ServerID])
REFERENCES [inventory].[Server] ([ServerID])
ALTER TABLE [inventory].[ServerContact] CHECK CONSTRAINT [FK_ServerContact_Server]
