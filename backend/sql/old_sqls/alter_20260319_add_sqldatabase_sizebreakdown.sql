USE SQLInventory;
GO

/*
  Adds size breakdown columns to inventory.SQLDatabase.
  Safe to run multiple times.
*/

IF COL_LENGTH('inventory.SQLDatabase', 'DataSizeGB') IS NULL
  ALTER TABLE inventory.SQLDatabase ADD DataSizeGB DECIMAL(18,2) NULL;
GO

IF COL_LENGTH('inventory.SQLDatabase', 'LogSizeGB') IS NULL
  ALTER TABLE inventory.SQLDatabase ADD LogSizeGB DECIMAL(18,2) NULL;
GO

IF COL_LENGTH('inventory.SQLDatabase', 'TotalSizeGB') IS NULL
  ALTER TABLE inventory.SQLDatabase ADD TotalSizeGB AS (ISNULL(DataSizeGB, 0) + ISNULL(LogSizeGB, 0)) PERSISTED;
GO

