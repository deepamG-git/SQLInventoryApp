/* User Creation for Portal Access */

DECLARE @Username VARCHAR(100) = 'Username';
DECLARE @PlainPassword VARCHAR(100) = 'P@ssWord';
DECLARE @Salt VARCHAR(64) = CONVERT(VARCHAR(64), NEWID());
DECLARE @Hash VARCHAR(64) = CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', CONCAT(@PlainPassword, @Salt)), 2);

IF NOT EXISTS (SELECT 1 FROM inventory.AppUser WHERE Username = @Username)
BEGIN
    INSERT INTO inventory.AppUser (Username, PasswordHash, PasswordSalt, IsActive)
    VALUES (@Username, @Hash, @Salt, 1);
END
GO
