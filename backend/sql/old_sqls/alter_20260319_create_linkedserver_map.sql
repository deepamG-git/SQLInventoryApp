USE SQLInventory;
GO

/*
  Optional mapping table: SQLInstance -> Linked Server name.
  If you do not populate this, stored procedures will fall back to:
    - Default instance: ServerName
    - Named instance:   ServerName\\InstanceName
  Safe to run multiple times.
*/

IF OBJECT_ID('inventory.SQLInstanceLinkedServer', 'U') IS NULL
BEGIN
  CREATE TABLE inventory.SQLInstanceLinkedServer
  (
    SQLInstanceID INT NOT NULL CONSTRAINT PK_SQLInstanceLinkedServer PRIMARY KEY,
    LinkedServerName SYSNAME NOT NULL,
    IsActive BIT NOT NULL CONSTRAINT DF_SQLInstanceLinkedServer_IsActive DEFAULT 1,
    CreatedDate DATETIME2 NOT NULL CONSTRAINT DF_SQLInstanceLinkedServer_CreatedDate DEFAULT SYSDATETIME(),
    CreatedBy VARCHAR(100) NULL,
    ModifiedDate DATETIME2 NULL,
    ModifiedBy VARCHAR(100) NULL,

    CONSTRAINT FK_SQLInstanceLinkedServer_SQLInstance FOREIGN KEY (SQLInstanceID) REFERENCES inventory.SQLInstance(SQLInstanceID)
  );

  CREATE UNIQUE INDEX UX_SQLInstanceLinkedServer_Name ON inventory.SQLInstanceLinkedServer(LinkedServerName);
END
GO

