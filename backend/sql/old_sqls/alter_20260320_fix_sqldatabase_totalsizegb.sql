USE SQLInventory;
GO

/*
  Fixes inventory.SQLDatabase.TotalSizeGB computed column so it remains meaningful
  when DataSizeGB/LogSizeGB are NULL (manual UI entry).

  New logic:
    If DataSizeGB and LogSizeGB are both NULL -> use SizeGB
    Else -> DataSizeGB + LogSizeGB

  Safe to run multiple times.
*/

IF COL_LENGTH('inventory.SQLDatabase', 'TotalSizeGB') IS NOT NULL
BEGIN
  ALTER TABLE inventory.SQLDatabase DROP COLUMN TotalSizeGB;
END
GO

ALTER TABLE inventory.SQLDatabase
ADD TotalSizeGB AS (
  CASE
    WHEN DataSizeGB IS NULL AND LogSizeGB IS NULL THEN ISNULL(SizeGB, 0)
    ELSE ISNULL(DataSizeGB, 0) + ISNULL(LogSizeGB, 0)
  END
) PERSISTED;
GO

