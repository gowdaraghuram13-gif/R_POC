/*
================================================================================
  05_usp_ConfigureLinkedServer.sql
  Description : Creates or reconfigures a linked server based on the generic
                connection configuration stored in dbo.ETL_ConnectionConfig.
                This makes the upstream connection fully configurable without
                changing any stored procedure code.
  Author      : Devin
  Created     : 2026-03-27
================================================================================
*/

USE [DW_POC];
GO

IF OBJECT_ID(N'dbo.usp_ConfigureLinkedServer', N'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_ConfigureLinkedServer;
GO

CREATE PROCEDURE dbo.usp_ConfigureLinkedServer
    @ConnectionName NVARCHAR(100) = N'UpstreamCRM'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ServerName         NVARCHAR(256);
    DECLARE @DatabaseName       NVARCHAR(128);
    DECLARE @ProviderName       NVARCHAR(128);
    DECLARE @AuthType           NVARCHAR(20);
    DECLARE @RemoteLoginUser    NVARCHAR(128);
    DECLARE @RemoteLoginPassword NVARCHAR(256);
    DECLARE @LinkedServerName   NVARCHAR(128);
    DECLARE @LogID              INT;
    DECLARE @ErrorMessage       NVARCHAR(4000);

    -- Log start
    INSERT INTO dbo.ETL_ExecutionLog (ProcedureName, StepName, Status)
    VALUES (N'usp_ConfigureLinkedServer', N'Start', N'Started');
    SET @LogID = SCOPE_IDENTITY();

    BEGIN TRY
        -- =====================================================================
        -- Step 1: Read connection config
        -- =====================================================================
        SELECT
            @ServerName          = ServerName,
            @DatabaseName        = DatabaseName,
            @ProviderName        = ProviderName,
            @AuthType            = AuthType,
            @RemoteLoginUser     = RemoteLoginUser,
            @RemoteLoginPassword = RemoteLoginPassword,
            @LinkedServerName    = LinkedServerName
        FROM dbo.ETL_ConnectionConfig
        WHERE ConnectionName = @ConnectionName
          AND IsActive = 1;

        IF @ServerName IS NULL
        BEGIN
            RAISERROR(N'No active connection configuration found for: %s', 16, 1, @ConnectionName);
            RETURN;
        END

        -- Generate a linked server name if not already set
        IF @LinkedServerName IS NULL
        BEGIN
            SET @LinkedServerName = N'LS_' + REPLACE(@ConnectionName, N' ', N'_');

            UPDATE dbo.ETL_ConnectionConfig
            SET LinkedServerName = @LinkedServerName,
                ModifiedDate     = GETDATE()
            WHERE ConnectionName = @ConnectionName;
        END

        -- =====================================================================
        -- Step 2: Drop existing linked server if it exists
        -- =====================================================================
        IF EXISTS (SELECT 1 FROM sys.servers WHERE name = @LinkedServerName)
        BEGIN
            EXEC master.dbo.sp_dropserver
                @server  = @LinkedServerName,
                @droplogins = N'droplogins';

            PRINT N'Dropped existing linked server: ' + @LinkedServerName;
        END

        -- =====================================================================
        -- Step 3: Create linked server
        -- =====================================================================
        EXEC master.dbo.sp_addlinkedserver
            @server     = @LinkedServerName,
            @srvproduct = N'',
            @provider   = @ProviderName,
            @datasrc    = @ServerName,
            @catalog    = @DatabaseName;

        -- =====================================================================
        -- Step 4: Configure login mapping
        -- =====================================================================
        IF @AuthType = N'SQL'
        BEGIN
            EXEC master.dbo.sp_addlinkedsrvlogin
                @rmtsrvname  = @LinkedServerName,
                @useself     = N'False',
                @locallogin  = NULL,
                @rmtuser     = @RemoteLoginUser,
                @rmtpassword = @RemoteLoginPassword;
        END
        ELSE
        BEGIN
            -- Windows authentication: use current security context
            EXEC master.dbo.sp_addlinkedsrvlogin
                @rmtsrvname = @LinkedServerName,
                @useself    = N'True';
        END

        -- =====================================================================
        -- Step 5: Set linked server options for better performance
        -- =====================================================================
        EXEC master.dbo.sp_serveroption @LinkedServerName, N'rpc out',           N'true';
        EXEC master.dbo.sp_serveroption @LinkedServerName, N'data access',       N'true';
        EXEC master.dbo.sp_serveroption @LinkedServerName, N'collation compatible', N'true';

        -- Log success
        UPDATE dbo.ETL_ExecutionLog
        SET Status  = N'Success',
            EndTime = GETDATE()
        WHERE LogID = @LogID;

        PRINT N'Linked server configured successfully: ' + @LinkedServerName;

    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ERROR_MESSAGE();

        UPDATE dbo.ETL_ExecutionLog
        SET Status       = N'Failed',
            ErrorMessage = @ErrorMessage,
            EndTime      = GETDATE()
        WHERE LogID = @LogID;

        RAISERROR(N'usp_ConfigureLinkedServer failed: %s', 16, 1, @ErrorMessage);
    END CATCH
END
GO

PRINT 'Stored procedure usp_ConfigureLinkedServer created successfully.';
GO
