USE SQLInventory;
GO

/*
  Creates inventory.SQLDatabase to store database inventory per SQL instance.
  Safe to run multiple times.
*/

IF OBJECT_ID('inventory.SQLDatabase', 'U') IS NULL
BEGIN
  CREATE TABLE inventory.SQLDatabase
  (
    SQLDatabaseID INT IDENTITY(1,1) CONSTRAINT PK_SQLDatabase PRIMARY KEY,
    SQLInstanceID INT NOT NULL,

    DatabaseName VARCHAR(256) NOT NULL,
    Owner VARCHAR(128) NULL,
    SizeGB DECIMAL(18,2) NULL,
    CreatedOn DATETIME2 NULL,
    RecoveryModel VARCHAR(30) NULL,
    DatabaseCollation VARCHAR(128) NULL,

    CDC BIT NOT NULL CONSTRAINT DF_SQLDatabase_CDC DEFAULT 0,
    CompatibilityLevel INT NULL,
    Encryption BIT NOT NULL CONSTRAINT DF_SQLDatabase_Encryption DEFAULT 0,
    QueryStore BIT NOT NULL CONSTRAINT DF_SQLDatabase_QueryStore DEFAULT 0,
    AutoUpdateStats BIT NOT NULL CONSTRAINT DF_SQLDatabase_AutoUpdateStats DEFAULT 1,

    IsActive BIT NOT NULL CONSTRAINT DF_SQLDatabase_IsActive DEFAULT 1,

    CreatedDate DATETIME2 NOT NULL CONSTRAINT DF_SQLDatabase_CreatedDate DEFAULT SYSDATETIME(),
    CreatedBy VARCHAR(100) NULL,
    ModifiedDate DATETIME2 NULL,
    ModifiedBy VARCHAR(100) NULL,

    CONSTRAINT FK_SQLDatabase_SQLInstance FOREIGN KEY (SQLInstanceID) REFERENCES inventory.SQLInstance(SQLInstanceID)
  );

  CREATE UNIQUE INDEX UX_SQLDatabase_Instance_DbName ON inventory.SQLDatabase(SQLInstanceID, DatabaseName);
  CREATE INDEX IX_SQLDatabase_InstanceID ON inventory.SQLDatabase(SQLInstanceID);
END
GO

