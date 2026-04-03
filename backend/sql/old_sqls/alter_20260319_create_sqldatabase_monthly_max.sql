USE SQLInventory;
GO

/*
  Stores monthly max size per DB per instance.
  YearMonth format: YYYY-MM
  Safe to run multiple times.
*/

IF OBJECT_ID('inventory.SQLDatabaseMonthlyMax', 'U') IS NULL
BEGIN
  CREATE TABLE inventory.SQLDatabaseMonthlyMax
  (
    YearMonth CHAR(7) NOT NULL,
    SQLInstanceID INT NOT NULL,
    DatabaseName VARCHAR(256) NOT NULL,

    MaxDataSizeGB DECIMAL(18,2) NULL,
    MaxLogSizeGB DECIMAL(18,2) NULL,
    MaxTotalSizeGB AS (ISNULL(MaxDataSizeGB, 0) + ISNULL(MaxLogSizeGB, 0)) PERSISTED,

    CalcDate DATETIME2 NOT NULL CONSTRAINT DF_SQLDatabaseMonthlyMax_CalcDate DEFAULT SYSDATETIME(),

    CONSTRAINT PK_SQLDatabaseMonthlyMax PRIMARY KEY (YearMonth, SQLInstanceID, DatabaseName),
    CONSTRAINT FK_SQLDatabaseMonthlyMax_SQLInstance FOREIGN KEY (SQLInstanceID) REFERENCES inventory.SQLInstance(SQLInstanceID)
  );

  CREATE INDEX IX_SQLDatabaseMonthlyMax_Instance ON inventory.SQLDatabaseMonthlyMax(SQLInstanceID, YearMonth);
END
GO

