/****** Object:  StoredProcedure [inventory].[usp_Email_DBTrend_Server]    Script Date: 03-04-2026 15:48:50 ******/
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON

/*
  Sends Database Trend report via SQL Server Database Mail (sp_send_dbmail).

  This is a reference implementation to match the backend endpoint:
    POST /api/db-trend/email-report

  Expected parameters from backend:
  - @Recipients
  - @ccRecipients (optional)
  - @ServerID
  - @MonthsBack (default 6, clamped 1..12 in API)

  Prereqs:
  - Database Mail configured and enabled on this SQL Server
  - inventory.SQLDatabaseMonthlyMax is populated (scheduled collectors)

  Notes:
  - This procedure renders the report as an HTML table in the email body (similar to Health Report).
  - Update the default profile selection logic if your environment requires a specific profile.
*/

CREATE   PROCEDURE inventory.usp_Email_DBTrend_Server
  @Recipients NVARCHAR(MAX),
  @ccRecipients NVARCHAR(MAX) = NULL,
  @ServerID INT,
  @MonthsBack INT = 6,
  @ProfileName SYSNAME = 'SQLMailProfile',
  @SubjectPrefix NVARCHAR(200) = N'SQL Database Trend'
AS
BEGIN
  SET NOCOUNT ON;

  IF @MonthsBack IS NULL OR @MonthsBack < 1 SET @MonthsBack = 6;
  IF @MonthsBack > 12 SET @MonthsBack = 12;

  DECLARE @ServerName NVARCHAR(200), @BU NVARCHAR(200), @Env NVARCHAR(50);
  SELECT
    @ServerName = s.ServerName,
    @BU = bu.BusinessUnitName,
    @Env = env.EnvName
  FROM inventory.Server s
  INNER JOIN inventory.BusinessUnit bu ON bu.BUID = s.BUID
  INNER JOIN inventory.Environment env ON env.EnvID = s.EnvID
  WHERE s.ServerID = @ServerID;

  IF @ServerName IS NULL
    RETURN;

  -- Pick a default Database Mail profile if not provided.
  IF @ProfileName IS NULL
  BEGIN
    SELECT TOP (1) @ProfileName = p.name
    FROM msdb.dbo.sysmail_profile p
    ORDER BY p.profile_id;
  END

  DECLARE @firstOfThisMonth DATE = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);
  DECLARE @startMonth DATE = DATEADD(MONTH, -(@MonthsBack - 1), @firstOfThisMonth);
  DECLARE @startYm CHAR(7) = CONVERT(CHAR(7), @startMonth, 120);      -- YYYY-MM
  DECLARE @endYm CHAR(7) = CONVERT(CHAR(7), @firstOfThisMonth, 120);  -- YYYY-MM

  DECLARE @months TABLE (SortOrder INT PRIMARY KEY, YearMonth CHAR(7) NOT NULL, Label NVARCHAR(20) NOT NULL);
  DECLARE @i INT = 0;
  WHILE @i < @MonthsBack
  BEGIN
    DECLARE @d DATE = DATEADD(MONTH, @i, @startMonth);
    INSERT INTO @months (SortOrder, YearMonth, Label)
    VALUES
    (
      @i,
      CONVERT(CHAR(7), @d, 120),
      LEFT(DATENAME(MONTH, @d), 3) + N'-' + CONVERT(NVARCHAR(4), YEAR(@d))
    );
    SET @i += 1;
  END

  -- Basic HTML escaping for free-text columns used in markup.
  DECLARE @escServer NVARCHAR(400) = REPLACE(REPLACE(REPLACE(@ServerName, N'&', N'&amp;'), N'<', N'&lt;'), N'>', N'&gt;');
  DECLARE @escBu NVARCHAR(400) = REPLACE(REPLACE(REPLACE(ISNULL(@BU, N''), N'&', N'&amp;'), N'<', N'&lt;'), N'>', N'&gt;');
  DECLARE @escEnv NVARCHAR(100) = REPLACE(REPLACE(REPLACE(ISNULL(@Env, N''), N'&', N'&amp;'), N'<', N'&lt;'), N'>', N'&gt;');

  DECLARE @html NVARCHAR(MAX) = N'';
  SET @html += N'<h2 style="margin-bottom:4px;">' + @escServer + N'</h2>';
  SET @html += N'<div style="color:#445; margin-bottom:10px;">' + @escBu + N' | ' + @escEnv + N'</div>';
  SET @html += N'<div style="color:#667; margin-bottom:12px;">Six-month comparison of monthly maximum database size, based on daily snapshots.</div>';
  SET @html += N'<div style="color:#667; margin-bottom:14px;">Range: ' + @startYm + N' to ' + @endYm + N' (MonthsBack=' + CONVERT(nvarchar(10), @MonthsBack) + N')</div>';

  SET @html += N'<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; font-family:Segoe UI, Arial; font-size:12px;">';
  SET @html += N'<tr style="background:#f3f6fb;">';
  SET @html += N'<th align="left">SQL Instance</th><th align="left">Database</th>';

  -- Month headers
  SELECT @html += (
    SELECT N'<th align="right">' + m.Label + N'</th>'
    FROM @months m
    ORDER BY m.SortOrder
    FOR XML PATH(''), TYPE
  ).value('.','nvarchar(max)');

  SET @html += N'<th align="right">% Change (6M)</th></tr>';

  ;WITH base AS (
    SELECT
      si.InstanceName,
      m.DatabaseName,
      m.YearMonth,
      CAST(m.MaxTotalSizeGB AS decimal(18,2)) AS MaxTotalSizeGB
    FROM inventory.SQLDatabaseMonthlyMax m
    INNER JOIN inventory.SQLInstance si ON si.SQLInstanceID = m.SQLInstanceID
    WHERE si.ServerID = @ServerID
      AND ISNULL(si.IsActive, 1) = 1
      AND m.YearMonth >= @startYm
      AND m.YearMonth <= @endYm
  ),
  combos AS (
    SELECT DISTINCT InstanceName, DatabaseName
    FROM base
  )
  SELECT @html += (
    SELECT
      N'<tr>' +
      N'<td>' + REPLACE(REPLACE(REPLACE(ISNULL(c.InstanceName, N''), N'&', N'&amp;'), N'<', N'&lt;'), N'>', N'&gt;') + N'</td>' +
      N'<td>' + REPLACE(REPLACE(REPLACE(ISNULL(c.DatabaseName, N''), N'&', N'&amp;'), N'<', N'&lt;'), N'>', N'&gt;') + N'</td>' +
      (
        SELECT
          N'<td align="right">' +
          ISNULL(CONVERT(nvarchar(32), v.MaxTotalSizeGB), N'') +
          N'</td>'
        FROM @months mm
        OUTER APPLY (
          SELECT TOP (1) b.MaxTotalSizeGB
          FROM base b
          WHERE b.InstanceName = c.InstanceName
            AND b.DatabaseName = c.DatabaseName
            AND b.YearMonth = mm.YearMonth
        ) v
        ORDER BY mm.SortOrder
        FOR XML PATH(''), TYPE
      ).value('.','nvarchar(max)') +
      (
        SELECT
          CASE
            WHEN s0.MaxTotalSizeGB IS NULL OR s1.MaxTotalSizeGB IS NULL OR s0.MaxTotalSizeGB <= 0 THEN N'<td align="right"></td>'
            ELSE
              CASE WHEN ((s1.MaxTotalSizeGB - s0.MaxTotalSizeGB) / s0.MaxTotalSizeGB) * 100.0 > 20
                THEN N'<td align="right" style="background:#f9e8ea; font-weight:700;">'
                ELSE N'<td align="right" style="background:#e9f8ef; font-weight:700;">'
              END +
              CONVERT(nvarchar(32), CAST(((s1.MaxTotalSizeGB - s0.MaxTotalSizeGB) / s0.MaxTotalSizeGB) * 100.0 AS decimal(18,2))) + N'%' +
              N'</td>'
          END
        FROM (SELECT TOP (1) b.MaxTotalSizeGB FROM base b WHERE b.InstanceName=c.InstanceName AND b.DatabaseName=c.DatabaseName AND b.YearMonth=@startYm) s0
        CROSS JOIN (SELECT TOP (1) b.MaxTotalSizeGB FROM base b WHERE b.InstanceName=c.InstanceName AND b.DatabaseName=c.DatabaseName AND b.YearMonth=@endYm) s1
      ) +
      N'</tr>'
    FROM combos c
    ORDER BY c.InstanceName, c.DatabaseName
    FOR XML PATH(''), TYPE
  ).value('.','nvarchar(max)');

  IF NOT EXISTS (
    SELECT 1
    FROM inventory.SQLDatabaseMonthlyMax m
    INNER JOIN inventory.SQLInstance si ON si.SQLInstanceID = m.SQLInstanceID
    WHERE si.ServerID = @ServerID
      AND ISNULL(si.IsActive, 1) = 1
      AND m.YearMonth >= @startYm
      AND m.YearMonth <= @endYm
  )
  BEGIN
    SET @html += N'<tr><td colspan="' + CONVERT(nvarchar(10), 3 + @MonthsBack) + N'" align="center" style="padding:12px; color:#667;">No trend data found for selected range.</td></tr>';
  END

  SET @html += N'</table>';

  DECLARE @emailsub NVARCHAR(500) = @SubjectPrefix + N' - ' +@ServerName;

  EXEC msdb.dbo.sp_send_dbmail
    @profile_name = @ProfileName,
    @recipients = @Recipients,
    @copy_recipients = @ccRecipients,
    @subject = @emailSub,
    @body = @html,
    @body_format = 'HTML';
END

