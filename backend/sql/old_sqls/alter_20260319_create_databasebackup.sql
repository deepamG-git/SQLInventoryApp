USE SQLInventory;
GO

/*
  Stores backup history pulled from remote msdb (successful backups).
  Safe to run multiple times.
*/

IF OBJECT_ID('inventory.DatabaseBackup', 'U') IS NULL
BEGIN
  CREATE TABLE inventory.DatabaseBackup
  (
    DatabaseBackupID BIGINT IDENTITY(1,1) CONSTRAINT PK_DatabaseBackup PRIMARY KEY,
    SQLInstanceID INT NOT NULL,
    DatabaseName VARCHAR(256) NOT NULL,
    BackupType CHAR(1) NOT NULL, -- D=Full, I=Diff, L=Log
    BackupStartDate DATETIME2 NOT NULL,
    BackupFinishDate DATETIME2 NOT NULL,
    BackupSizeMB DECIMAL(18,2) NULL,
    IsCopyOnly BIT NOT NULL CONSTRAINT DF_DatabaseBackup_IsCopyOnly DEFAULT 0,
    BackupSetID INT NOT NULL,

    CollectedDate DATE NOT NULL CONSTRAINT DF_DatabaseBackup_CollectedDate DEFAULT CONVERT(date, SYSDATETIME()),
    CreatedDate DATETIME2 NOT NULL CONSTRAINT DF_DatabaseBackup_CreatedDate DEFAULT SYSDATETIME(),

    CONSTRAINT FK_DatabaseBackup_SQLInstance FOREIGN KEY (SQLInstanceID) REFERENCES inventory.SQLInstance(SQLInstanceID)
  );

  CREATE UNIQUE INDEX UX_DatabaseBackup_Instance_BackupSet ON inventory.DatabaseBackup(SQLInstanceID, BackupSetID);
  CREATE INDEX IX_DatabaseBackup_Instance_Finish ON inventory.DatabaseBackup(SQLInstanceID, BackupFinishDate);
END
GO

