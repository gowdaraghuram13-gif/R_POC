/*
================================================================================
  07_usp_LoadDimCustomer.sql
  Description : Transforms staged customer data and loads it into the DimCustomer
                dimension table using MERGE (SCD Type 1 - overwrite).

                Transformations applied:
                  1. FullName        = LTRIM(RTRIM(FirstName)) + ' ' + LTRIM(RTRIM(LastName))
                  2. Age             = Calculated from DateOfBirth with birthday adjustment
                  3. IncomeCategory  = CASE on AnnualIncome (Low / Medium / High / Very High)
                  4. CustomerSegment = CASE on TotalPurchaseAmount (Bronze / Silver / Gold / Platinum)
                  5. IsActive        = 1 when AccountStatus = 'Active', else 0

  Author      : Devin
  Created     : 2026-03-27
================================================================================
*/

USE [DW_POC];
GO

IF OBJECT_ID(N'dbo.usp_LoadDimCustomer', N'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_LoadDimCustomer;
GO

CREATE PROCEDURE dbo.usp_LoadDimCustomer
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @InsertCount    INT = 0;
    DECLARE @UpdateCount    INT = 0;
    DECLARE @LogID          INT;
    DECLARE @ErrorMessage   NVARCHAR(4000);

    -- Log start
    INSERT INTO dbo.ETL_ExecutionLog (ProcedureName, StepName, Status)
    VALUES (N'usp_LoadDimCustomer', N'Start', N'Started');
    SET @LogID = SCOPE_IDENTITY();

    BEGIN TRY
        -- =====================================================================
        -- Create temp table to capture MERGE OUTPUT counts
        -- =====================================================================
        CREATE TABLE #MergeOutput ([action] NVARCHAR(10));

        -- =====================================================================
        -- Use MERGE to upsert into DimCustomer (SCD Type 1)
        -- =====================================================================
        ;MERGE dbo.DimCustomer AS tgt
        USING
        (
            SELECT
                -- === 1:1 Mapped Columns ===
                s.CustomerID,
                s.FirstName,
                s.LastName,
                s.Email,
                s.Phone,
                s.DateOfBirth,
                s.Gender,
                s.MaritalStatus,
                s.AddressLine1,
                s.AddressLine2,
                s.City,
                s.StateProvince,
                s.PostalCode,
                s.Country,
                s.AnnualIncome,
                s.TotalPurchaseAmount,
                s.AccountOpenDate,
                s.AccountStatus,

                -- =============================================================
                -- TRANSFORMATION 1: FullName
                -- Concatenates first and last name with proper trimming.
                -- Handles NULLs gracefully using COALESCE.
                -- =============================================================
                LTRIM(RTRIM(
                    COALESCE(s.FirstName, N'') +
                    CASE
                        WHEN s.FirstName IS NOT NULL AND s.LastName IS NOT NULL
                        THEN N' '
                        ELSE N''
                    END +
                    COALESCE(s.LastName, N'')
                )) AS FullName,

                -- =============================================================
                -- TRANSFORMATION 2: Age
                -- Calculates age from DateOfBirth with birthday correction.
                -- If DOB is in the future or NULL, returns NULL.
                -- =============================================================
                CASE
                    WHEN s.DateOfBirth IS NULL THEN NULL
                    WHEN s.DateOfBirth > GETDATE() THEN NULL
                    ELSE DATEDIFF(YEAR, s.DateOfBirth, GETDATE())
                         - CASE
                               WHEN DATEADD(YEAR,
                                    DATEDIFF(YEAR, s.DateOfBirth, GETDATE()),
                                    s.DateOfBirth) > GETDATE()
                               THEN 1
                               ELSE 0
                           END
                END AS Age,

                -- =============================================================
                -- TRANSFORMATION 3: IncomeCategory
                -- Categorizes annual income into buckets:
                --   < 30,000       => Low
                --   30,000-74,999  => Medium
                --   75,000-149,999 => High
                --   >= 150,000     => Very High
                -- =============================================================
                CASE
                    WHEN s.AnnualIncome IS NULL       THEN N'Unknown'
                    WHEN s.AnnualIncome < 30000       THEN N'Low'
                    WHEN s.AnnualIncome < 75000       THEN N'Medium'
                    WHEN s.AnnualIncome < 150000      THEN N'High'
                    ELSE                                   N'Very High'
                END AS IncomeCategory,

                -- =============================================================
                -- TRANSFORMATION 4: CustomerSegment
                -- Segments customers by total purchase amount:
                --   < 1,000        => Bronze
                --   1,000-9,999    => Silver
                --   10,000-49,999  => Gold
                --   >= 50,000      => Platinum
                -- =============================================================
                CASE
                    WHEN s.TotalPurchaseAmount IS NULL       THEN N'Unknown'
                    WHEN s.TotalPurchaseAmount < 1000        THEN N'Bronze'
                    WHEN s.TotalPurchaseAmount < 10000       THEN N'Silver'
                    WHEN s.TotalPurchaseAmount < 50000       THEN N'Gold'
                    ELSE                                          N'Platinum'
                END AS CustomerSegment,

                -- =============================================================
                -- TRANSFORMATION 5: IsActive
                -- Converts AccountStatus text into a boolean flag.
                --   'Active' => 1, everything else => 0
                -- =============================================================
                CASE
                    WHEN UPPER(s.AccountStatus) = N'ACTIVE' THEN 1
                    ELSE 0
                END AS IsActive

            FROM dbo.Staging_Customer AS s
        ) AS src
        ON tgt.CustomerID = src.CustomerID

        -- === UPDATE existing rows (SCD Type 1: overwrite) ===
        WHEN MATCHED AND
        (
            ISNULL(tgt.FirstName, N'')          <> ISNULL(src.FirstName, N'')
            OR ISNULL(tgt.LastName, N'')        <> ISNULL(src.LastName, N'')
            OR ISNULL(tgt.Email, N'')           <> ISNULL(src.Email, N'')
            OR ISNULL(tgt.Phone, N'')           <> ISNULL(src.Phone, N'')
            OR ISNULL(tgt.Gender, N'')          <> ISNULL(src.Gender, N'')
            OR ISNULL(tgt.MaritalStatus, N'')   <> ISNULL(src.MaritalStatus, N'')
            OR ISNULL(tgt.AddressLine1, N'')    <> ISNULL(src.AddressLine1, N'')
            OR ISNULL(tgt.City, N'')            <> ISNULL(src.City, N'')
            OR ISNULL(tgt.StateProvince, N'')   <> ISNULL(src.StateProvince, N'')
            OR ISNULL(tgt.Country, N'')         <> ISNULL(src.Country, N'')
            OR ISNULL(tgt.AnnualIncome, 0)      <> ISNULL(src.AnnualIncome, 0)
            OR ISNULL(tgt.TotalPurchaseAmount, 0) <> ISNULL(src.TotalPurchaseAmount, 0)
            OR ISNULL(tgt.AccountStatus, N'')   <> ISNULL(src.AccountStatus, N'')
        )
        THEN UPDATE SET
            tgt.FirstName           = src.FirstName,
            tgt.LastName            = src.LastName,
            tgt.FullName            = src.FullName,
            tgt.Email               = src.Email,
            tgt.Phone               = src.Phone,
            tgt.DateOfBirth         = src.DateOfBirth,
            tgt.Age                 = src.Age,
            tgt.Gender              = src.Gender,
            tgt.MaritalStatus       = src.MaritalStatus,
            tgt.AddressLine1        = src.AddressLine1,
            tgt.AddressLine2        = src.AddressLine2,
            tgt.City                = src.City,
            tgt.StateProvince       = src.StateProvince,
            tgt.PostalCode          = src.PostalCode,
            tgt.Country             = src.Country,
            tgt.AnnualIncome        = src.AnnualIncome,
            tgt.IncomeCategory      = src.IncomeCategory,
            tgt.TotalPurchaseAmount = src.TotalPurchaseAmount,
            tgt.CustomerSegment     = src.CustomerSegment,
            tgt.AccountOpenDate     = src.AccountOpenDate,
            tgt.AccountStatus       = src.AccountStatus,
            tgt.IsActive            = src.IsActive,
            tgt.LoadDate            = GETDATE()

        -- === INSERT new rows ===
        WHEN NOT MATCHED BY TARGET
        THEN INSERT
        (
            CustomerID, FirstName, LastName, FullName,
            Email, Phone, DateOfBirth, Age,
            Gender, MaritalStatus,
            AddressLine1, AddressLine2, City, StateProvince, PostalCode, Country,
            AnnualIncome, IncomeCategory,
            TotalPurchaseAmount, CustomerSegment,
            AccountOpenDate, AccountStatus, IsActive,
            LoadDate
        )
        VALUES
        (
            src.CustomerID, src.FirstName, src.LastName, src.FullName,
            src.Email, src.Phone, src.DateOfBirth, src.Age,
            src.Gender, src.MaritalStatus,
            src.AddressLine1, src.AddressLine2, src.City, src.StateProvince, src.PostalCode, src.Country,
            src.AnnualIncome, src.IncomeCategory,
            src.TotalPurchaseAmount, src.CustomerSegment,
            src.AccountOpenDate, src.AccountStatus, src.IsActive,
            GETDATE()
        )

        -- Capture counts via OUTPUT
        OUTPUT $action INTO #MergeOutput;

        -- =====================================================================
        -- Count inserts and updates from OUTPUT results
        -- =====================================================================
        SELECT @InsertCount = COUNT(*) FROM #MergeOutput WHERE [action] = N'INSERT';
        SELECT @UpdateCount = COUNT(*) FROM #MergeOutput WHERE [action] = N'UPDATE';
        DROP TABLE #MergeOutput;

        -- =====================================================================
        -- Log success
        -- =====================================================================
        UPDATE dbo.ETL_ExecutionLog
        SET Status       = N'Success',
            RowsAffected = @InsertCount + @UpdateCount,
            EndTime      = GETDATE(),
            StepName     = N'Inserts: ' + CAST(@InsertCount AS NVARCHAR(10))
                         + N', Updates: ' + CAST(@UpdateCount AS NVARCHAR(10))
        WHERE LogID = @LogID;

        PRINT N'DimCustomer load completed. Inserted: '
            + CAST(@InsertCount AS NVARCHAR(10))
            + N', Updated: '
            + CAST(@UpdateCount AS NVARCHAR(10));

    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ERROR_MESSAGE();

        UPDATE dbo.ETL_ExecutionLog
        SET Status       = N'Failed',
            ErrorMessage = @ErrorMessage,
            EndTime      = GETDATE()
        WHERE LogID = @LogID;

        -- Clean up temp table if it exists
        IF OBJECT_ID(N'tempdb..#MergeOutput') IS NOT NULL
            DROP TABLE #MergeOutput;

        RAISERROR(N'usp_LoadDimCustomer failed: %s', 16, 1, @ErrorMessage);
    END CATCH
END
GO

PRINT 'Stored procedure usp_LoadDimCustomer created successfully.';
GO
