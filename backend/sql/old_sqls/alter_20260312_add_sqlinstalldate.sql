USE SQLInventory;
GO

/*
  Adds SQLInstallDate to inventory.SQLInstance for tracking the install date of each SQL instance.
  Safe to run multiple times.
*/

IF COL_LENGTH('inventory.SQLInstance', 'SQLInstallDate') IS NULL
BEGIN
  ALTER TABLE inventory.SQLInstance
    ADD SQLInstallDate date NULL;
END
GO

