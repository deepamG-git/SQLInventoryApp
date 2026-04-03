USE SQLInventory;
GO

/*
  Stores maintenance/DBA job last-run status per day (snapshot).
  Safe to run multiple times.
*/

IF OBJECT_ID('inventory.SQLMaintenanceJobRun', 'U') IS NULL
BEGIN
  CREATE TABLE inventory.SQLMaintenanceJobRun
  (
    SnapshotDate DATE NOT NULL CONSTRAINT DF_SQLMaintenanceJobRun_SnapshotDate DEFAULT CONVERT(date, SYSDATETIME()),
    SQLInstanceID INT NOT NULL,
    JobName VARCHAR(256) NOT NULL,

    LastRunDateTime DATETIME2 NULL,
    LastRunDurationSec INT NULL,
    LastRunStatus VARCHAR(30) NULL,
    LastRunMessage VARCHAR(4000) NULL,

    CreatedDate DATETIME2 NOT NULL CONSTRAINT DF_SQLMaintenanceJobRun_CreatedDate DEFAULT SYSDATETIME(),

    CONSTRAINT PK_SQLMaintenanceJobRun PRIMARY KEY (SnapshotDate, SQLInstanceID, JobName),
    CONSTRAINT FK_SQLMaintenanceJobRun_SQLInstance FOREIGN KEY (SQLInstanceID) REFERENCES inventory.SQLInstance(SQLInstanceID)
  );

  CREATE INDEX IX_SQLMaintenanceJobRun_Instance ON inventory.SQLMaintenanceJobRun(SQLInstanceID, SnapshotDate);
END
GO

