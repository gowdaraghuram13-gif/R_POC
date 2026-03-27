/*
================================================================================
  02_SourceCustomer.sql
  Description : Creates the upstream source customer table. This represents the
                table that exists in the remote/upstream system. Provided here
                for reference and local testing purposes.
  Author      : Devin
  Created     : 2026-03-27
================================================================================
*/

USE [DW_POC];
GO

-- =============================================================================
-- Source Customer Table (simulates upstream system)
-- =============================================================================
IF OBJECT_ID(N'dbo.Source_Customer', N'U') IS NOT NULL
    DROP TABLE dbo.Source_Customer;
GO

CREATE TABLE dbo.Source_Customer
(
    CustomerID              NVARCHAR(20)    NOT NULL,   -- Business key
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
    AccountStatus           NVARCHAR(20)    NULL,       -- Active, Inactive, Closed, Suspended
    PreferredContactMethod  NVARCHAR(50)    NULL,       -- Email, Phone, Mail, SMS
    LastModifiedDate        DATETIME        NULL DEFAULT GETDATE(),
    CONSTRAINT PK_Source_Customer PRIMARY KEY CLUSTERED (CustomerID)
);
GO

-- =============================================================================
-- Insert sample data for testing
-- =============================================================================
INSERT INTO dbo.Source_Customer
(
    CustomerID, FirstName, LastName, Email, Phone, DateOfBirth,
    Gender, MaritalStatus, AddressLine1, AddressLine2,
    City, StateProvince, PostalCode, Country,
    AnnualIncome, TotalPurchaseAmount, AccountOpenDate,
    AccountStatus, PreferredContactMethod
)
VALUES
    (N'CUST-001', N'John',    N'Smith',     N'john.smith@example.com',    N'555-0101', '1985-03-15', N'Male',   N'Married',  N'123 Main St',       N'Apt 4B',   N'New York',     N'NY', N'10001', N'USA', 85000.00,  12500.00,  '2018-01-10', N'Active',    N'Email'),
    (N'CUST-002', N'Jane',    N'Doe',       N'jane.doe@example.com',      N'555-0102', '1990-07-22', N'Female', N'Single',   N'456 Oak Ave',       NULL,        N'Los Angeles',  N'CA', N'90001', N'USA', 62000.00,  8300.50,   '2019-05-20', N'Active',    N'Phone'),
    (N'CUST-003', N'Robert',  N'Johnson',   N'r.johnson@example.com',     N'555-0103', '1978-11-03', N'Male',   N'Divorced', N'789 Pine Rd',       N'Suite 12', N'Chicago',      N'IL', N'60601', N'USA', 120000.00, 55000.00,  '2015-09-01', N'Active',    N'Email'),
    (N'CUST-004', N'Maria',   N'Garcia',    N'maria.garcia@example.com',  N'555-0104', '1995-02-14', N'Female', N'Single',   N'321 Elm Blvd',      NULL,        N'Houston',      N'TX', N'77001', N'USA', 28000.00,  450.75,    '2022-03-15', N'Active',    N'SMS'),
    (N'CUST-005', N'David',   N'Williams',  N'dwilliams@example.com',     N'555-0105', '1982-09-30', N'Male',   N'Married',  N'654 Maple Dr',      N'Unit 7',   N'Phoenix',      N'AZ', N'85001', N'USA', 95000.00,  23000.00,  '2017-11-08', N'Inactive',  N'Mail'),
    (N'CUST-006', N'Sarah',   N'Brown',     N'sarah.brown@example.com',   N'555-0106', '1988-06-18', N'Female', N'Married',  N'987 Cedar Ln',      NULL,        N'Philadelphia', N'PA', N'19101', N'USA', 155000.00, 78000.00,  '2016-02-28', N'Active',    N'Email'),
    (N'CUST-007', N'Michael', N'Jones',     N'mjones@example.com',        N'555-0107', '2001-01-05', N'Male',   N'Single',   N'147 Birch Way',     N'Apt 2A',   N'San Antonio',  N'TX', N'78201', N'USA', 42000.00,  1200.00,   '2023-07-01', N'Active',    N'Phone'),
    (N'CUST-008', N'Emily',   N'Davis',     N'emily.davis@example.com',   N'555-0108', '1975-12-25', N'Female', N'Widowed',  N'258 Walnut St',     NULL,        N'San Diego',    N'CA', N'92101', N'USA', 73000.00,  9800.00,   '2014-04-10', N'Closed',    N'Mail'),
    (N'CUST-009', N'James',   N'Wilson',    N'j.wilson@example.com',      N'555-0109', '1993-04-08', N'Male',   N'Single',   N'369 Spruce Ave',    N'Floor 3',  N'Dallas',       N'TX', N'75201', N'USA', 58000.00,  3400.00,   '2020-10-22', N'Suspended', N'SMS'),
    (N'CUST-010', N'Lisa',    N'Martinez',  N'lisa.martinez@example.com', N'555-0110', '1970-08-19', N'Female', N'Married',  N'741 Redwood Ct',    NULL,        N'San Jose',     N'CA', N'95101', N'USA', 210000.00, 125000.00, '2012-06-15', N'Active',    N'Email');
GO

PRINT 'Source_Customer table created and sample data inserted.';
GO
