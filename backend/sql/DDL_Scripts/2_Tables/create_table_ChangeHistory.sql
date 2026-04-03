/****** Object:  Table [inventory].[ChangeHistory]    Script Date: 03-04-2026 15:48:44 ******/
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
CREATE TABLE [inventory].[ChangeHistory](
	[ChangeID] [int] IDENTITY(1,1) NOT NULL,
	[EntityName] [varchar](100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[RecordID] [int] NOT NULL,
	[FieldName] [varchar](100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[OldValue] [varchar](max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[NewValue] [varchar](max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[ChangedBy] [varchar](100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[ChangedDate] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_ChangeHistory] PRIMARY KEY CLUSTERED 
(
	[ChangeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

SET ANSI_PADDING ON

/****** Object:  Index [IX_ChangeHistory_Record]    Script Date: 03-04-2026 15:48:44 ******/
CREATE NONCLUSTERED INDEX [IX_ChangeHistory_Record] ON [inventory].[ChangeHistory]
(
	[EntityName] ASC,
	[RecordID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
ALTER TABLE [inventory].[ChangeHistory] ADD  DEFAULT (sysdatetime()) FOR [ChangedDate]
