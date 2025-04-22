-- Smoke test for the Hessra PostgreSQL extension
-- This script verifies that the extension loads properly and creates all necessary objects

-- Connect to the test database
\c hessra_test

-- Set the output format to be more readable
\pset format aligned
\pset tuples_only off

-- Print a header
SELECT '======= HESSRA EXTENSION SMOKE TEST =======';

-- Check if the extension is installed
SELECT 'Checking if extension is installed...' AS operation;
SELECT EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'hessra_authz'
) AS extension_installed;

-- Check if the expected tables are created by the extension
SELECT 'Checking if required tables exist...' AS operation;
SELECT 'hessra_public_keys' AS table_name, 
       EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'hessra_public_keys') AS exists;
SELECT 'hessra_service_chains' AS table_name, 
       EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'hessra_service_chains') AS exists;

-- Check if the required functions are available
SELECT 'Checking if required functions exist...' AS operation;
SELECT 'verify_hessra_token' AS function_name, 
       EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'verify_hessra_token') AS exists;
SELECT 'verify_hessra_service_chain' AS function_name, 
       EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'verify_hessra_service_chain') AS exists;
SELECT 'verify_hessra_service_chain_by_name' AS function_name, 
       EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'verify_hessra_service_chain_by_name') AS exists;
SELECT 'get_service_chain_json' AS function_name, 
       EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_service_chain_json') AS exists;

-- Verify the tables have the expected structure
SELECT 'Checking hessra_public_keys table structure...' AS operation;
\d hessra_public_keys

SELECT 'Checking hessra_service_chains table structure...' AS operation;
\d hessra_service_chains

-- Comprehensive extension smoke test result
SELECT 'Comprehensive extension status check...' AS operation;
DO $$
DECLARE
    extension_installed BOOLEAN;
    table1_exists BOOLEAN;
    table2_exists BOOLEAN;
    function1_exists BOOLEAN;
    function2_exists BOOLEAN;
    function3_exists BOOLEAN;
    function4_exists BOOLEAN;
    all_checks_passed BOOLEAN;
BEGIN
    -- Check if extension is installed
    SELECT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'hessra_authz')
    INTO extension_installed;
    
    -- Check tables
    SELECT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'hessra_public_keys')
    INTO table1_exists;
    
    SELECT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'hessra_service_chains')
    INTO table2_exists;
    
    -- Check functions
    SELECT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'verify_hessra_token')
    INTO function1_exists;
    
    SELECT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'verify_hessra_service_chain')
    INTO function2_exists;
    
    SELECT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'verify_hessra_service_chain_by_name')
    INTO function3_exists;
    
    SELECT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_service_chain_json')
    INTO function4_exists;
    
    -- Overall status
    all_checks_passed := extension_installed AND table1_exists AND table2_exists AND 
                       function1_exists AND function2_exists AND function3_exists AND function4_exists;
    
    IF all_checks_passed THEN
        RAISE NOTICE 'SMOKE TEST PASSED: All components of the extension are properly installed.';
    ELSE
        RAISE EXCEPTION 'SMOKE TEST FAILED: Some components of the extension are missing.
            Extension installed: %
            hessra_public_keys table: %
            hessra_service_chains table: %
            verify_hessra_token function: %
            verify_hessra_service_chain function: %
            verify_hessra_service_chain_by_name function: %
            get_service_chain_json function: %',
            extension_installed, table1_exists, table2_exists, 
            function1_exists, function2_exists, function3_exists, function4_exists;
    END IF;
END $$;

-- Final message
SELECT '======= SMOKE TEST COMPLETED ======='; 