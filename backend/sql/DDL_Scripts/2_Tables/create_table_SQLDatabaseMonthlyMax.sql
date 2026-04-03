/****** Object:  Table [inventory].[SQLDatabaseMonthlyMax]    Script Date: 03-04-2026 15:48:46 ******/
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
CREATE TABLE [inventory].[SQLDatabaseMonthlyMax](
	[YearMonth] [char](7) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[SQLInstanceID] [int] NOT NULL,
	[DatabaseName] [varchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[MaxDataSizeGB] [decimal](18, 2) NULL,
	[MaxLogSizeGB] [decimal](18, 2) NULL,
	[MaxTotalSizeGB]  AS (isnull([MaxDataSizeGB],(0))+isnull([MaxLogSizeGB],(0))) PERSISTED,
	[CalcDate] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_SQLDatabaseMonthlyMax] PRIMARY KEY CLUSTERED 
(
	[YearMonth] ASC,
	[SQLInstanceID] ASC,
	[DatabaseName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

SET ANSI_PADDING ON

/****** Object:  Index [IX_SQLDatabaseMonthlyMax_Instance]    Script Date: 03-04-2026 15:48:46 ******/
CREATE NONCLUSTERED INDEX [IX_SQLDatabaseMonthlyMax_Instance] ON [inventory].[SQLDatabaseMonthlyMax]
(
	[SQLInstanceID] ASC,
	[YearMonth] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
ALTER TABLE [inventory].[SQLDatabaseMonthlyMax] ADD  CONSTRAINT [DF_SQLDatabaseMonthlyMax_CalcDate]  DEFAULT (sysdatetime()) FOR [CalcDate]
ALTER TABLE [inventory].[SQLDatabaseMonthlyMax]  WITH CHECK ADD  CONSTRAINT [FK_SQLDatabaseMonthlyMax_SQLInstance] FOREIGN KEY([SQLInstanceID])
REFERENCES [inventory].[SQLInstance] ([SQLInstanceID])
ALTER TABLE [inventory].[SQLDatabaseMonthlyMax] CHECK CONSTRAINT [FK_SQLDatabaseMonthlyMax_SQLInstance]
