-- ============================================================
-- T-SQL Script to enable CDC (Change Data Capture) on SQL Server
-- Database: MySimpleDB_Tsql
-- Required for Debezium to stream real-time changes
-- ============================================================

-- Switch to the database
USE MySimpleDB_Tsql;
GO

-- ============================================================
-- Step 1: Enable CDC on the database
-- ============================================================
EXEC sys.sp_cdc_enable_db;
PRINT 'CDC enabled on MySimpleDB_Tsql database.';
GO

-- ============================================================
-- Step 2: Enable CDC on the truck_locations table
-- ============================================================
EXEC sys.sp_cdc_enable_table
    @source_schema = 'dbo',
    @source_name = 'truck_locations',
    @role_name = NULL,
    @supports_net_changes = 1;
PRINT 'CDC enabled on truck_locations table.';
GO

-- ============================================================
-- Verify CDC is enabled
-- ============================================================

-- Check database CDC status
SELECT name, is_cdc_enabled 
FROM sys.databases 
WHERE name = 'MySimpleDB_Tsql';

-- Check table CDC status
SELECT name, is_tracked_by_cdc 
FROM sys.tables 
WHERE name = 'truck_locations';

-- List CDC capture instances
SELECT * FROM cdc.change_tables;
GO

PRINT 'CDC setup complete!';
GO

