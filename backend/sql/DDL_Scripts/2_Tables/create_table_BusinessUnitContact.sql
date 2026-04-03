/****** Object:  Table [inventory].[BusinessUnitContact]    Script Date: 03-04-2026 15:48:44 ******/
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
CREATE TABLE [inventory].[BusinessUnitContact](
	[BUID] [int] NOT NULL,
	[ContactID] [int] NOT NULL,
	[ContactCategoryID] [int] NOT NULL,
 CONSTRAINT [PK_BUContact] PRIMARY KEY CLUSTERED 
(
	[BUID] ASC,
	[ContactID] ASC,
	[ContactCategoryID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

ALTER TABLE [inventory].[BusinessUnitContact]  WITH CHECK ADD  CONSTRAINT [FK_BUC_BU] FOREIGN KEY([BUID])
REFERENCES [inventory].[BusinessUnit] ([BUID])
ALTER TABLE [inventory].[BusinessUnitContact] CHECK CONSTRAINT [FK_BUC_BU]
ALTER TABLE [inventory].[BusinessUnitContact]  WITH CHECK ADD  CONSTRAINT [FK_BUC_Category] FOREIGN KEY([ContactCategoryID])
REFERENCES [inventory].[ContactCategory] ([ContactCategoryID])
ALTER TABLE [inventory].[BusinessUnitContact] CHECK CONSTRAINT [FK_BUC_Category]
ALTER TABLE [inventory].[BusinessUnitContact]  WITH CHECK ADD  CONSTRAINT [FK_BUC_Contact] FOREIGN KEY([ContactID])
REFERENCES [inventory].[Contact] ([ContactID])
ALTER TABLE [inventory].[BusinessUnitContact] CHECK CONSTRAINT [FK_BUC_Contact]
