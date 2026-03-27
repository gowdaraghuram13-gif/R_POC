/*
================================================================================
  01_ConnectionConfig.sql
  Description : Creates a generic connection configuration table to store
                upstream data source connection details. This allows the ETL
                process to be driven by configuration rather than hard-coded
                connection strings.
  Author      : Devin
  Created     : 2026-03-27
================================================================================
*/

USE [master];
GO

-- Create the target database if it does not exist
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = N'DW_POC')
BEGIN
    CREATE DATABASE [DW_POC];
END
GO

USE [DW_POC];
GO

-- =============================================================================
-- Connection Configuration Table
-- =============================================================================
IF OBJECT_ID(N'dbo.ETL_ConnectionConfig', N'U') IS NOT NULL
    DROP TABLE dbo.ETL_ConnectionConfig;
GO

CREATE TABLE dbo.ETL_ConnectionConfig
(
    ConfigID            INT IDENTITY(1, 1)  NOT NULL,
    ConnectionName      NVARCHAR(100)       NOT NULL,   -- Friendly name (e.g. 'UpstreamCRM')
    ServerName          NVARCHAR(256)       NOT NULL,   -- Remote server hostname / IP
    DatabaseName        NVARCHAR(128)       NOT NULL,   -- Remote database name
    SchemaName          NVARCHAR(128)       NOT NULL DEFAULT N'dbo',
    ProviderName        NVARCHAR(128)       NOT NULL DEFAULT N'SQLNCLI11',  -- OLE DB provider
    AuthType            NVARCHAR(20)        NOT NULL DEFAULT N'SQL',        -- SQL or Windows
    RemoteLoginUser     NVARCHAR(128)       NULL,       -- SQL login (NULL for Windows auth)
    RemoteLoginPassword NVARCHAR(256)       NULL,       -- Encrypted or placeholder
    LinkedServerName    NVARCHAR(128)       NULL,       -- Auto-populated by config SP
    IsActive            BIT                 NOT NULL DEFAULT 1,
    CreatedDate         DATETIME            NOT NULL DEFAULT GETDATE(),
    ModifiedDate        DATETIME            NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_ETL_ConnectionConfig PRIMARY KEY CLUSTERED (ConfigID),
    CONSTRAINT UQ_ConnectionName UNIQUE (ConnectionName)
);
GO

-- =============================================================================
-- ETL Execution Log Table
-- =============================================================================
IF OBJECT_ID(N'dbo.ETL_ExecutionLog', N'U') IS NOT NULL
    DROP TABLE dbo.ETL_ExecutionLog;
GO

CREATE TABLE dbo.ETL_ExecutionLog
(
    LogID               INT IDENTITY(1, 1)  NOT NULL,
    ProcedureName       NVARCHAR(256)       NOT NULL,
    StepName            NVARCHAR(256)       NULL,
    Status              NVARCHAR(20)        NOT NULL,   -- Started, Success, Failed
    RowsAffected        INT                 NULL,
    ErrorMessage        NVARCHAR(4000)      NULL,
    StartTime           DATETIME            NOT NULL DEFAULT GETDATE(),
    EndTime             DATETIME            NULL,
    CONSTRAINT PK_ETL_ExecutionLog PRIMARY KEY CLUSTERED (LogID)
);
GO

-- =============================================================================
-- Seed a sample connection configuration row
-- =============================================================================
INSERT INTO dbo.ETL_ConnectionConfig
(
    ConnectionName,
    ServerName,
    DatabaseName,
    SchemaName,
    ProviderName,
    AuthType,
    RemoteLoginUser,
    RemoteLoginPassword
)
VALUES
(
    N'UpstreamCRM',
    N'UPSTREAM-SERVER',          -- Replace with actual server name
    N'CRM_Database',             -- Replace with actual database name
    N'dbo',
    N'SQLNCLI11',
    N'SQL',
    N'etl_reader',               -- Replace with actual login
    N'<<REPLACE_WITH_PASSWORD>>' -- Replace with actual password
);
GO

PRINT 'Connection configuration table created and seeded successfully.';
GO
