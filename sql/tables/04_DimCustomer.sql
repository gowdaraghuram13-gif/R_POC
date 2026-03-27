/*
================================================================================
  04_DimCustomer.sql
  Description : Creates the DimCustomer dimension table with 25 columns.
                - 19 columns are direct 1:1 mappings from the source
                - 5 columns are derived via transformations
                - 1 column is an ETL metadata column (LoadDate)
  Author      : Devin
  Created     : 2026-03-27
================================================================================
*/

USE [DW_POC];
GO

-- =============================================================================
-- DimCustomer Dimension Table (25 columns)
-- =============================================================================
IF OBJECT_ID(N'dbo.DimCustomer', N'U') IS NOT NULL
    DROP TABLE dbo.DimCustomer;
GO

CREATE TABLE dbo.DimCustomer
(
    -- === Surrogate Key ===
    CustomerKey             INT IDENTITY(1, 1)  NOT NULL,   -- Col  1: Surrogate key

    -- === Business Key (1:1 mapping) ===
    CustomerID              NVARCHAR(20)        NOT NULL,   -- Col  2: Business key from source

    -- === Direct 1:1 Mapped Columns ===
    FirstName               NVARCHAR(100)       NULL,       -- Col  3: Direct mapping
    LastName                NVARCHAR(100)       NULL,       -- Col  4: Direct mapping

    -- === TRANSFORMATION: Concatenation of FirstName + LastName ===
    FullName                NVARCHAR(201)       NULL,       -- Col  5: TRANSFORMED

    Email                   NVARCHAR(256)       NULL,       -- Col  6: Direct mapping
    Phone                   NVARCHAR(50)        NULL,       -- Col  7: Direct mapping
    DateOfBirth             DATE                NULL,       -- Col  8: Direct mapping

    -- === TRANSFORMATION: Calculated from DateOfBirth ===
    Age                     INT                 NULL,       -- Col  9: TRANSFORMED

    Gender                  NVARCHAR(10)        NULL,       -- Col 10: Direct mapping
    MaritalStatus           NVARCHAR(20)        NULL,       -- Col 11: Direct mapping
    AddressLine1            NVARCHAR(256)       NULL,       -- Col 12: Direct mapping
    AddressLine2            NVARCHAR(256)       NULL,       -- Col 13: Direct mapping
    City                    NVARCHAR(100)       NULL,       -- Col 14: Direct mapping
    StateProvince           NVARCHAR(100)       NULL,       -- Col 15: Direct mapping
    PostalCode              NVARCHAR(20)        NULL,       -- Col 16: Direct mapping
    Country                 NVARCHAR(100)       NULL,       -- Col 17: Direct mapping
    AnnualIncome            DECIMAL(18, 2)      NULL,       -- Col 18: Direct mapping

    -- === TRANSFORMATION: Categorized from AnnualIncome ===
    IncomeCategory          NVARCHAR(20)        NULL,       -- Col 19: TRANSFORMED

    TotalPurchaseAmount     DECIMAL(18, 2)      NULL,       -- Col 20: Direct mapping

    -- === TRANSFORMATION: Segmented from TotalPurchaseAmount ===
    CustomerSegment         NVARCHAR(20)        NULL,       -- Col 21: TRANSFORMED

    AccountOpenDate         DATE                NULL,       -- Col 22: Direct mapping
    AccountStatus           NVARCHAR(20)        NULL,       -- Col 23: Direct mapping

    -- === TRANSFORMATION: Derived from AccountStatus ===
    IsActive                BIT                 NOT NULL DEFAULT 0,  -- Col 24: TRANSFORMED

    -- === ETL Metadata ===
    LoadDate                DATETIME            NOT NULL DEFAULT GETDATE(),  -- Col 25: System

    -- === Constraints ===
    CONSTRAINT PK_DimCustomer PRIMARY KEY CLUSTERED (CustomerKey),
    CONSTRAINT UQ_DimCustomer_CustomerID UNIQUE (CustomerID)
);
GO

-- =============================================================================
-- Indexes for common query patterns
-- =============================================================================
CREATE NONCLUSTERED INDEX IX_DimCustomer_CustomerSegment
    ON dbo.DimCustomer (CustomerSegment)
    INCLUDE (CustomerID, FullName, IsActive);
GO

CREATE NONCLUSTERED INDEX IX_DimCustomer_IsActive
    ON dbo.DimCustomer (IsActive)
    INCLUDE (CustomerID, FullName, CustomerSegment);
GO

CREATE NONCLUSTERED INDEX IX_DimCustomer_IncomeCategory
    ON dbo.DimCustomer (IncomeCategory)
    INCLUDE (CustomerID, AnnualIncome);
GO

PRINT 'DimCustomer dimension table created successfully (25 columns).';
GO
