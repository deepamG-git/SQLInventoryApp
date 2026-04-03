/****** Object:  StoredProcedure [inventory].[usp_Calc_SQLDatabaseMonthlyMax]    Script Date: 03-04-2026 15:48:50 ******/
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON

/*
  Calculates monthly max database size from inventory.SQLDatabaseDailySnapshot
  and upserts into inventory.SQLDatabaseMonthlyMax.

  Default: last 6 months including current month-to-date.
*/

CREATE   PROCEDURE [inventory].[usp_Calc_SQLDatabaseMonthlyMax]
  @MonthsBack INT = 6
AS
BEGIN
  SET NOCOUNT ON;

  IF @MonthsBack IS NULL OR @MonthsBack < 1 SET @MonthsBack = 6;

  DECLARE @start DATE = DATEFROMPARTS(YEAR(DATEADD(month, -(@MonthsBack - 1), CAST(SYSDATETIME() AS date))), MONTH(DATEADD(month, -(@MonthsBack - 1), CAST(SYSDATETIME() AS date))), 1);

  ;WITH agg AS (
    SELECT
      CONVERT(char(7), SnapshotDate, 126) AS YearMonth,
      SQLInstanceID,
      DatabaseName,
      MAX(DataSizeGB) AS MaxDataSizeGB,
      MAX(LogSizeGB) AS MaxLogSizeGB
    FROM inventory.SQLDatabaseDailySnapshot
    WHERE SnapshotDate >= @start
    GROUP BY CONVERT(char(7), SnapshotDate, 126), SQLInstanceID, DatabaseName
  )
  MERGE inventory.SQLDatabaseMonthlyMax AS tgt
  USING agg AS src
  ON tgt.YearMonth = src.YearMonth AND tgt.SQLInstanceID = src.SQLInstanceID AND tgt.DatabaseName = src.DatabaseName
  WHEN MATCHED THEN
    UPDATE SET
      tgt.MaxDataSizeGB = src.MaxDataSizeGB,
      tgt.MaxLogSizeGB = src.MaxLogSizeGB,
      tgt.CalcDate = SYSDATETIME()
  WHEN NOT MATCHED THEN
    INSERT (YearMonth, SQLInstanceID, DatabaseName, MaxDataSizeGB, MaxLogSizeGB)
    VALUES (src.YearMonth, src.SQLInstanceID, src.DatabaseName, src.MaxDataSizeGB, src.MaxLogSizeGB);
END


