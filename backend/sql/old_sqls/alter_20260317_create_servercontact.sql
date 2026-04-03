USE SQLInventory;
GO

/*
  Creates inventory.ServerContact mapping table to support server-specific contacts.
  Safe to run multiple times.
*/

IF OBJECT_ID('inventory.ServerContact', 'U') IS NULL
BEGIN
  CREATE TABLE inventory.ServerContact
  (
    ServerID INT NOT NULL,
    ContactID INT NOT NULL,
    ContactCategoryID INT NOT NULL,

    CreatedDate DATETIME2 NOT NULL CONSTRAINT DF_ServerContact_CreatedDate DEFAULT SYSDATETIME(),
    CreatedBy VARCHAR(100) NULL,

    CONSTRAINT PK_ServerContact PRIMARY KEY (ServerID, ContactID, ContactCategoryID),
    CONSTRAINT FK_ServerContact_Server FOREIGN KEY (ServerID) REFERENCES inventory.Server(ServerID),
    CONSTRAINT FK_ServerContact_Contact FOREIGN KEY (ContactID) REFERENCES inventory.Contact(ContactID),
    CONSTRAINT FK_ServerContact_Category FOREIGN KEY (ContactCategoryID) REFERENCES inventory.ContactCategory(ContactCategoryID)
  );

  CREATE INDEX IX_ServerContact_ServerID ON inventory.ServerContact(ServerID);
  CREATE INDEX IX_ServerContact_ContactID ON inventory.ServerContact(ContactID);
END
GO

