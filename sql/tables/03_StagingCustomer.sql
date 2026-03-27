/*
================================================================================
  03_StagingCustomer.sql
  Description : Creates the staging table used as an intermediate landing zone
                for data extracted from the upstream source system. This table
                mirrors the source schema and is truncated before each load.
  Author      : Devin
  Created     : 2026-03-27
================================================================================
*/

USE [DW_POC];
GO

-- =============================================================================
-- Staging Customer Table
-- =============================================================================
IF OBJECT_ID(N'dbo.Staging_Customer', N'U') IS NOT NULL
    DROP TABLE dbo.Staging_Customer;
GO

CREATE TABLE dbo.Staging_Customer
(
    CustomerID              NVARCHAR(20)    NOT NULL,
    FirstName               NVARCHAR(100)   NULL,
    LastName                NVARCHAR(100)   NULL,
    Email                   NVARCHAR(256)   NULL,
    Phone                   NVARCHAR(50)    NULL,
    DateOfBirth             DATE            NULL,
    Gender                  NVARCHAR(10)    NULL,
    MaritalStatus           NVARCHAR(20)    NULL,
    AddressLine1            NVARCHAR(256)   NULL,
    AddressLine2            NVARCHAR(256)   NULL,
    City                    NVARCHAR(100)   NULL,
    StateProvince           NVARCHAR(100)   NULL,
    PostalCode              NVARCHAR(20)    NULL,
    Country                 NVARCHAR(100)   NULL,
    AnnualIncome            DECIMAL(18, 2)  NULL,
    TotalPurchaseAmount     DECIMAL(18, 2)  NULL,
    AccountOpenDate         DATE            NULL,
    AccountStatus           NVARCHAR(20)    NULL,
    PreferredContactMethod  NVARCHAR(50)    NULL,
    LastModifiedDate        DATETIME        NULL,
    CONSTRAINT PK_Staging_Customer PRIMARY KEY CLUSTERED (CustomerID)
);
GO

-- Index to speed up lookups during the merge/load step
CREATE NONCLUSTERED INDEX IX_Staging_Customer_Status
    ON dbo.Staging_Customer (AccountStatus);
GO

PRINT 'Staging_Customer table created successfully.';
GO
