USE SQLInventory;
GO

/*
  Stores daily database size snapshots per SQL instance.
  Safe to run multiple times.
*/

IF OBJECT_ID('inventory.SQLDatabaseDailySnapshot', 'U') IS NULL
BEGIN
  CREATE TABLE inventory.SQLDatabaseDailySnapshot
  (
    SnapshotDate DATE NOT NULL,
    SQLInstanceID INT NOT NULL,
    DatabaseName VARCHAR(256) NOT NULL,

    DataSizeGB DECIMAL(18,2) NULL,
    LogSizeGB DECIMAL(18,2) NULL,
    TotalSizeGB AS (ISNULL(DataSizeGB, 0) + ISNULL(LogSizeGB, 0)) PERSISTED,

    CreatedDate DATETIME2 NOT NULL CONSTRAINT DF_SQLDatabaseDailySnapshot_CreatedDate DEFAULT SYSDATETIME(),

    CONSTRAINT PK_SQLDatabaseDailySnapshot PRIMARY KEY (SnapshotDate, SQLInstanceID, DatabaseName),
    CONSTRAINT FK_SQLDatabaseDailySnapshot_SQLInstance FOREIGN KEY (SQLInstanceID) REFERENCES inventory.SQLInstance(SQLInstanceID)
  );

  CREATE INDEX IX_SQLDatabaseDailySnapshot_Instance ON inventory.SQLDatabaseDailySnapshot(SQLInstanceID, SnapshotDate);
END
GO

