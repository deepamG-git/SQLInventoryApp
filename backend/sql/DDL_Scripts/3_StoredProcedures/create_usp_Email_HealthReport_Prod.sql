/****** Object:  StoredProcedure [inventory].[usp_Email_HealthReport_Prod]    Script Date: 03-04-2026 15:48:50 ******/
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON


CREATE   PROCEDURE inventory.usp_Email_HealthReport_Prod
  @ProfileName SYSNAME,
  @Recipients NVARCHAR(MAX),
  @OnlyBUID INT = NULL
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @sid INT;
  DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT s.ServerID
    FROM inventory.Server s
    INNER JOIN inventory.Environment env ON env.EnvID = s.EnvID
    INNER JOIN inventory.ServerStatus ss ON ss.StatusID = s.StatusID
    WHERE env.EnvName = 'PROD'
      AND ss.StatusName = 'IN USE'
      AND (@OnlyBUID IS NULL OR s.BUID = @OnlyBUID)
    ORDER BY s.ServerName;

  OPEN cur;
  FETCH NEXT FROM cur INTO @sid;
  WHILE @@FETCH_STATUS = 0
  BEGIN
    BEGIN TRY
      EXEC inventory.usp_Email_HealthReport_Server
        @ProfileName=@ProfileName,
        @Recipients=@Recipients,
        @ServerID=@sid,
        @SubjectPrefix=N'SQL Health Report';
    END TRY
    BEGIN CATCH
      PRINT CONCAT('Email failed for ServerID=', @sid, ' Error=', ERROR_MESSAGE());
    END CATCH;

    FETCH NEXT FROM cur INTO @sid;
  END

  CLOSE cur;
  DEALLOCATE cur;
END

