/*
================================================================================
  08_usp_MasterETL_DimCustomer.sql
  Description : Master orchestration stored procedure that runs the full ETL
                pipeline for loading the DimCustomer dimension table.

                Pipeline steps:
                  1. Extract data from upstream source into Staging_Customer
                  2. Transform and load from Staging_Customer into DimCustomer

                Includes full error handling, execution logging, and optional
                parameters for controlling the pipeline behavior.
  Author      : Devin
  Created     : 2026-03-27
================================================================================
*/

USE [DW_POC];
GO

IF OBJECT_ID(N'dbo.usp_MasterETL_DimCustomer', N'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_MasterETL_DimCustomer;
GO

CREATE PROCEDURE dbo.usp_MasterETL_DimCustomer
    @ConnectionName NVARCHAR(100) = N'UpstreamCRM',
    @UseLocalSource BIT           = 0,
    @SkipExtract    BIT           = 0       -- Set to 1 to skip extract (reuse staging data)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MasterLogID    INT;
    DECLARE @StepLogID      INT;
    DECLARE @ErrorMessage   NVARCHAR(4000);
    DECLARE @StartTime      DATETIME = GETDATE();

    -- =========================================================================
    -- Master Log Entry
    -- =========================================================================
    INSERT INTO dbo.ETL_ExecutionLog (ProcedureName, StepName, Status)
    VALUES (N'usp_MasterETL_DimCustomer', N'Pipeline Start', N'Started');
    SET @MasterLogID = SCOPE_IDENTITY();

    PRINT N'========================================================';
    PRINT N'  DimCustomer ETL Pipeline - Started at ' + CONVERT(NVARCHAR(30), @StartTime, 120);
    PRINT N'  Connection: ' + @ConnectionName;
    PRINT N'  Local Source Mode: ' + CASE @UseLocalSource WHEN 1 THEN N'YES' ELSE N'NO' END;
    PRINT N'========================================================';

    BEGIN TRY
        -- =====================================================================
        -- STEP 1: Extract from upstream source to staging
        -- =====================================================================
        IF @SkipExtract = 0
        BEGIN
            PRINT N'';
            PRINT N'--- Step 1: Extracting to Staging ---';

            INSERT INTO dbo.ETL_ExecutionLog (ProcedureName, StepName, Status)
            VALUES (N'usp_MasterETL_DimCustomer', N'Step 1: Extract', N'Started');
            SET @StepLogID = SCOPE_IDENTITY();

            EXEC dbo.usp_ExtractToStaging
                @ConnectionName = @ConnectionName,
                @UseLocalSource = @UseLocalSource;

            UPDATE dbo.ETL_ExecutionLog
            SET Status  = N'Success',
                EndTime = GETDATE()
            WHERE LogID = @StepLogID;

            PRINT N'--- Step 1: Complete ---';
        END
        ELSE
        BEGIN
            PRINT N'';
            PRINT N'--- Step 1: SKIPPED (SkipExtract = 1) ---';
        END

        -- =====================================================================
        -- STEP 2: Transform and load into DimCustomer
        -- =====================================================================
        PRINT N'';
        PRINT N'--- Step 2: Loading DimCustomer ---';

        INSERT INTO dbo.ETL_ExecutionLog (ProcedureName, StepName, Status)
        VALUES (N'usp_MasterETL_DimCustomer', N'Step 2: Load', N'Started');
        SET @StepLogID = SCOPE_IDENTITY();

        EXEC dbo.usp_LoadDimCustomer;

        UPDATE dbo.ETL_ExecutionLog
        SET Status  = N'Success',
            EndTime = GETDATE()
        WHERE LogID = @StepLogID;

        PRINT N'--- Step 2: Complete ---';

        -- =====================================================================
        -- Pipeline complete
        -- =====================================================================
        UPDATE dbo.ETL_ExecutionLog
        SET Status  = N'Success',
            EndTime = GETDATE()
        WHERE LogID = @MasterLogID;

        PRINT N'';
        PRINT N'========================================================';
        PRINT N'  DimCustomer ETL Pipeline - COMPLETED SUCCESSFULLY';
        PRINT N'  Duration: ' + CAST(DATEDIFF(SECOND, @StartTime, GETDATE()) AS NVARCHAR(10)) + N' seconds';
        PRINT N'========================================================';

    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ERROR_MESSAGE();

        -- Log the failure at the master level
        UPDATE dbo.ETL_ExecutionLog
        SET Status       = N'Failed',
            ErrorMessage = @ErrorMessage,
            EndTime      = GETDATE()
        WHERE LogID = @MasterLogID;

        PRINT N'';
        PRINT N'========================================================';
        PRINT N'  DimCustomer ETL Pipeline - FAILED';
        PRINT N'  Error: ' + @ErrorMessage;
        PRINT N'========================================================';

        RAISERROR(N'usp_MasterETL_DimCustomer failed: %s', 16, 1, @ErrorMessage);
    END CATCH
END
GO

PRINT 'Stored procedure usp_MasterETL_DimCustomer created successfully.';
GO
