USE SQLInventory;
GO

/*
  Changes inventory.ServerStorage size columns to DECIMAL(18,2) to support fractional GB.
  Safe to run multiple times.
*/

IF EXISTS (
  SELECT 1
  FROM sys.columns c
  INNER JOIN sys.types t ON t.user_type_id = c.user_type_id
  WHERE c.object_id = OBJECT_ID('inventory.ServerStorage')
    AND c.name IN ('TotalSizeGB','FreeSpaceGB')
    AND t.name = 'int'
)
BEGIN
  ALTER TABLE inventory.ServerStorage ALTER COLUMN TotalSizeGB DECIMAL(18,2) NOT NULL;
  ALTER TABLE inventory.ServerStorage ALTER COLUMN FreeSpaceGB DECIMAL(18,2) NOT NULL;
END
GO

