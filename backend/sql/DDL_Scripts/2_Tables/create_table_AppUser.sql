/****** Object:  Table [inventory].[AppUser]    Script Date: 03-04-2026 15:48:43 ******/
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
CREATE TABLE [inventory].[AppUser](
	[UserID] [int] IDENTITY(1,1) NOT NULL,
	[Username] [varchar](100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[PasswordHash] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[PasswordSalt] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedDate] [datetime2](7) NOT NULL,
	[UserRole] [varchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
 CONSTRAINT [PK_AppUser] PRIMARY KEY CLUSTERED 
(
	[UserID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

SET ANSI_PADDING ON

/****** Object:  Index [UX_AppUser_Username]    Script Date: 03-04-2026 15:48:43 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_AppUser_Username] ON [inventory].[AppUser]
(
	[Username] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
ALTER TABLE [inventory].[AppUser] ADD  CONSTRAINT [DF_AppUser_IsActive]  DEFAULT ((1)) FOR [IsActive]
ALTER TABLE [inventory].[AppUser] ADD  CONSTRAINT [DF_AppUser_CreatedDate]  DEFAULT (sysdatetime()) FOR [CreatedDate]
ALTER TABLE [inventory].[AppUser] ADD  CONSTRAINT [DF_AppUser_UserRole_Alter]  DEFAULT ('readonly') FOR [UserRole]
