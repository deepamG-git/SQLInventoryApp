USE SQLInventory;
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id WHERE s.name = 'inventory' AND t.name = 'AppUser')
BEGIN
    CREATE TABLE inventory.AppUser
    (
        UserID INT IDENTITY(1,1) CONSTRAINT PK_AppUser PRIMARY KEY,
        Username VARCHAR(100) NOT NULL,
        PasswordHash VARCHAR(64) NOT NULL,
        PasswordSalt VARCHAR(64) NOT NULL,
        UserRole VARCHAR(20) NOT NULL CONSTRAINT DF_AppUser_UserRole DEFAULT 'readonly',
        IsActive BIT NOT NULL CONSTRAINT DF_AppUser_IsActive DEFAULT 1,
        CreatedDate DATETIME2 NOT NULL CONSTRAINT DF_AppUser_CreatedDate DEFAULT SYSDATETIME()
    );

    CREATE UNIQUE INDEX UX_AppUser_Username ON inventory.AppUser(Username);
END
GO

IF COL_LENGTH('inventory.AppUser', 'UserRole') IS NULL
BEGIN
    ALTER TABLE inventory.AppUser
    ADD UserRole VARCHAR(20) NOT NULL CONSTRAINT DF_AppUser_UserRole_Alter DEFAULT 'readonly';
END
GO

/* Seed one user (replace values before running in production) */
DECLARE @Username VARCHAR(100) = 'admin';
DECLARE @PlainPassword VARCHAR(100) = 'ChangeMe@123';
DECLARE @Salt VARCHAR(64) = CONVERT(VARCHAR(64), NEWID());
DECLARE @Hash VARCHAR(64) = CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', CONCAT(@PlainPassword, @Salt)), 2);

IF NOT EXISTS (SELECT 1 FROM inventory.AppUser WHERE Username = @Username)
BEGIN
    INSERT INTO inventory.AppUser (Username, PasswordHash, PasswordSalt, UserRole, IsActive)
    VALUES (@Username, @Hash, @Salt, 'admin', 1);
END
GO
