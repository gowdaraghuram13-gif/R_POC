# R_POC - DimCustomer ETL Stored Procedures

SQL Server stored procedures for loading a `DimCustomer` dimension table from an upstream source system.

## Overview

This project contains SQL scripts to:
1. Configure a generic connection to an upstream data source (via Linked Server)
2. Extract customer data from the upstream source into a staging table
3. Transform and load the data into the `DimCustomer` dimension table (SCD Type 1)

## DimCustomer Table (25 Columns)

| # | Column | Source | Type |
|---|--------|--------|------|
| 1 | CustomerKey | Auto-generated surrogate key | IDENTITY |
| 2 | CustomerID | 1:1 mapping | Business key |
| 3 | FirstName | 1:1 mapping | Direct |
| 4 | LastName | 1:1 mapping | Direct |
| 5 | **FullName** | **Transformation**: `FirstName + ' ' + LastName` | Derived |
| 6 | Email | 1:1 mapping | Direct |
| 7 | Phone | 1:1 mapping | Direct |
| 8 | DateOfBirth | 1:1 mapping | Direct |
| 9 | **Age** | **Transformation**: Calculated from `DateOfBirth` | Derived |
| 10 | Gender | 1:1 mapping | Direct |
| 11 | MaritalStatus | 1:1 mapping | Direct |
| 12 | AddressLine1 | 1:1 mapping | Direct |
| 13 | AddressLine2 | 1:1 mapping | Direct |
| 14 | City | 1:1 mapping | Direct |
| 15 | StateProvince | 1:1 mapping | Direct |
| 16 | PostalCode | 1:1 mapping | Direct |
| 17 | Country | 1:1 mapping | Direct |
| 18 | AnnualIncome | 1:1 mapping | Direct |
| 19 | **IncomeCategory** | **Transformation**: CASE on `AnnualIncome` (Low/Medium/High/Very High) | Derived |
| 20 | TotalPurchaseAmount | 1:1 mapping | Direct |
| 21 | **CustomerSegment** | **Transformation**: CASE on `TotalPurchaseAmount` (Bronze/Silver/Gold/Platinum) | Derived |
| 22 | AccountOpenDate | 1:1 mapping | Direct |
| 23 | AccountStatus | 1:1 mapping | Direct |
| 24 | **IsActive** | **Transformation**: Derived from `AccountStatus` (1 if Active, else 0) | Derived |
| 25 | LoadDate | ETL metadata timestamp | System |

## Folder Structure

```
sql/
  config/
    01_ConnectionConfig.sql        -- Generic connection configuration table & linked server setup
  tables/
    02_SourceCustomer.sql          -- Upstream source table (reference/testing)
    03_StagingCustomer.sql         -- Staging table for extracted data
    04_DimCustomer.sql             -- Target dimension table (25 columns)
  stored_procedures/
    05_usp_ConfigureLinkedServer.sql   -- Configure linked server connection
    06_usp_ExtractToStaging.sql        -- Extract from upstream to staging
    07_usp_LoadDimCustomer.sql         -- Transform & load into DimCustomer
    08_usp_MasterETL_DimCustomer.sql   -- Master orchestration procedure
```

## Execution Order

1. Run `sql/config/01_ConnectionConfig.sql` to create the connection config table
2. Run `sql/tables/` scripts in order to create source, staging, and dimension tables
3. Run `sql/stored_procedures/` scripts in order to create all procedures
4. Execute `EXEC dbo.usp_ConfigureLinkedServer` to set up the linked server
5. Execute `EXEC dbo.usp_MasterETL_DimCustomer` to run the full ETL pipeline

## Transformations

- **FullName**: Concatenates `FirstName` and `LastName` with proper TRIM and NULL handling
- **Age**: Calculates age from `DateOfBirth` using `DATEDIFF` with birthday adjustment
- **IncomeCategory**: Categorizes `AnnualIncome` into Low (<30K), Medium (30-75K), High (75-150K), Very High (>150K)
- **CustomerSegment**: Segments customers by `TotalPurchaseAmount` into Bronze (<1K), Silver (1-10K), Gold (10-50K), Platinum (>50K)
- **IsActive**: Converts `AccountStatus` text to BIT flag (1 = Active, 0 = otherwise)
