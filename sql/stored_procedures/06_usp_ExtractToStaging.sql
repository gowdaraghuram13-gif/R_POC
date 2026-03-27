/*
================================================================================
  06_usp_ExtractToStaging.sql
  Description : Extracts customer data from the upstream source system into the
                local staging table. Uses the linked server configured via
                dbo.ETL_ConnectionConfig for a generic, configurable connection.
                Supports both linked-server mode (production) and local-source
                mode (testing / same-server scenarios).
  Author      : Devin
  Created     : 2026-03-27
================================================================================
*/

USE [DW_POC];
GO

IF OBJECT_ID(N'dbo.usp_ExtractToStaging', N'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_ExtractToStaging;
GO

CREATE PROCEDURE dbo.usp_ExtractToStaging
    @ConnectionName NVARCHAR(100) = N'UpstreamCRM',
    @UseLocalSource BIT           = 0               -- Set to 1 for local/testing mode
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LinkedServerName   NVARCHAR(128);
    DECLARE @DatabaseName       NVARCHAR(128);
    DECLARE @SchemaName         NVARCHAR(128);
    DECLARE @SQL                NVARCHAR(MAX);
    DECLARE @RowCount           INT;
    DECLARE @LogID              INT;
    DECLARE @ErrorMessage       NVARCHAR(4000);

    -- Log start
    INSERT INTO dbo.ETL_ExecutionLog (ProcedureName, StepName, Status)
    VALUES (N'usp_ExtractToStaging', N'Start', N'Started');
    SET @LogID = SCOPE_IDENTITY();

    BEGIN TRY
        -- =====================================================================
        -- Step 1: Read connection config
        -- =====================================================================
        SELECT
            @LinkedServerName = LinkedServerName,
            @DatabaseName     = DatabaseName,
            @SchemaName       = SchemaName
        FROM dbo.ETL_ConnectionConfig
        WHERE ConnectionName = @ConnectionName
          AND IsActive = 1;

        IF @UseLocalSource = 0 AND @LinkedServerName IS NULL
        BEGIN
            RAISERROR(N'No linked server configured for connection: %s. Run usp_ConfigureLinkedServer first.', 16, 1, @ConnectionName);
            RETURN;
        END

        -- =====================================================================
        -- Step 2: Truncate staging table
        -- =====================================================================
        TRUNCATE TABLE dbo.Staging_Customer;

        INSERT INTO dbo.ETL_ExecutionLog (ProcedureName, StepName, Status)
        VALUES (N'usp_ExtractToStaging', N'Truncate Staging', N'Success');

        -- =====================================================================
        -- Step 3: Extract data from source into staging
        -- =====================================================================
        IF @UseLocalSource = 1
        BEGIN
            -- Local mode: read from Source_Customer in the same database
            INSERT INTO dbo.Staging_Customer
            (
                CustomerID, FirstName, LastName, Email, Phone, DateOfBirth,
                Gender, MaritalStatus, AddressLine1, AddressLine2,
                City, StateProvince, PostalCode, Country,
                AnnualIncome, TotalPurchaseAmount, AccountOpenDate,
                AccountStatus, PreferredContactMethod, LastModifiedDate
            )
            SELECT
                CustomerID, FirstName, LastName, Email, Phone, DateOfBirth,
                Gender, MaritalStatus, AddressLine1, AddressLine2,
                City, StateProvince, PostalCode, Country,
                AnnualIncome, TotalPurchaseAmount, AccountOpenDate,
                AccountStatus, PreferredContactMethod, LastModifiedDate
            FROM dbo.Source_Customer;

            SET @RowCount = @@ROWCOUNT;
        END
        ELSE
        BEGIN
            -- Linked Server mode: read from remote source via dynamic SQL
            SET @SQL = N'
                INSERT INTO dbo.Staging_Customer
                (
                    CustomerID, FirstName, LastName, Email, Phone, DateOfBirth,
                    Gender, MaritalStatus, AddressLine1, AddressLine2,
                    City, StateProvince, PostalCode, Country,
                    AnnualIncome, TotalPurchaseAmount, AccountOpenDate,
                    AccountStatus, PreferredContactMethod, LastModifiedDate
                )
                SELECT
                    CustomerID, FirstName, LastName, Email, Phone, DateOfBirth,
                    Gender, MaritalStatus, AddressLine1, AddressLine2,
                    City, StateProvince, PostalCode, Country,
                    AnnualIncome, TotalPurchaseAmount, AccountOpenDate,
                    AccountStatus, PreferredContactMethod, LastModifiedDate
                FROM [' + @LinkedServerName + N'].[' + @DatabaseName + N'].[' + @SchemaName + N'].[Source_Customer];';

            EXEC sp_executesql @SQL;

            SET @RowCount = @@ROWCOUNT;
        END

        -- =====================================================================
        -- Step 4: Log success
        -- =====================================================================
        UPDATE dbo.ETL_ExecutionLog
        SET Status       = N'Success',
            RowsAffected = @RowCount,
            EndTime      = GETDATE()
        WHERE LogID = @LogID;

        PRINT N'Extract to staging completed. Rows loaded: ' + CAST(@RowCount AS NVARCHAR(10));

    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ERROR_MESSAGE();

        UPDATE dbo.ETL_ExecutionLog
        SET Status       = N'Failed',
            ErrorMessage = @ErrorMessage,
            EndTime      = GETDATE()
        WHERE LogID = @LogID;

        RAISERROR(N'usp_ExtractToStaging failed: %s', 16, 1, @ErrorMessage);
    END CATCH
END
GO

PRINT 'Stored procedure usp_ExtractToStaging created successfully.';
GO
