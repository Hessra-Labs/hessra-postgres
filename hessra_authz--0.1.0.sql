---
-- SQL definitions for the postgres-plugin extension
---

-- Protect against nesting or direct execution
\echo Use "CREATE EXTENSION hessra_authz" to load this file. \quit

-- Function to verify Hessra token with mandatory subject and resource
CREATE FUNCTION verify_hessra_token(token TEXT, subject TEXT, resource TEXT)
RETURNS BOOLEAN
AS '$libdir/hessra_authz', 'pg_verify_hessra_token'
LANGUAGE C STRICT IMMUTABLE;

-- Function to verify Hessra service chain token with mandatory service_nodes_json and component
CREATE FUNCTION verify_hessra_service_chain(token TEXT, subject TEXT, resource TEXT, service_nodes_json TEXT, component TEXT)
RETURNS BOOLEAN
AS '$libdir/hessra_authz', 'pg_verify_hessra_service_chain'
LANGUAGE C STRICT IMMUTABLE;

-- Function to set the public key path for Hessra authentication
-- This will set the custom configuration parameter that the C functions will check
CREATE OR REPLACE FUNCTION set_hessra_public_key_path(path TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    param_exists BOOLEAN;
BEGIN
    -- Check if the parameter exists (was properly registered by _PG_init)
    SELECT EXISTS (
        SELECT 1 FROM pg_settings WHERE name = 'hessra.public_key_path'
    ) INTO param_exists;
    
    -- If parameter doesn't exist, try to reload the extension
    IF NOT param_exists THEN
        RAISE WARNING 'Parameter hessra.public_key_path is not registered. The extension might need to be reloaded.';
        RETURN false;
    END IF;
    
    -- Set at session level
    PERFORM set_config('hessra.public_key_path', path, false);
    
    -- Return success
    RETURN true;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Failed to set hessra.public_key_path: %', SQLERRM;
        RETURN false;
END;
$$ LANGUAGE plpgsql STRICT;

-- Function to set the public key path globally (requires superuser privileges)
CREATE OR REPLACE FUNCTION set_hessra_public_key_path_global(path TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    param_exists BOOLEAN;
BEGIN
    -- Check if the parameter exists (was properly registered by _PG_init)
    SELECT EXISTS (
        SELECT 1 FROM pg_settings WHERE name = 'hessra.public_key_path'
    ) INTO param_exists;
    
    -- If parameter doesn't exist, try to reload the extension
    IF NOT param_exists THEN
        RAISE WARNING 'Parameter hessra.public_key_path is not registered. The extension might need to be reloaded.';
        RETURN false;
    END IF;

    -- Check if user has permission
    IF NOT pg_catalog.has_database_privilege(current_user, 'postgres', 'CREATE') THEN
        RAISE EXCEPTION 'Superuser privileges required to set global configuration';
    END IF;
    
    -- Set globally (persists between sessions)
    EXECUTE 'ALTER SYSTEM SET hessra.public_key_path = ' || quote_literal(path);
    
    -- Make it available to new sessions without restart
    PERFORM pg_catalog.pg_reload_conf();
    
    -- Also set for current session
    PERFORM set_config('hessra.public_key_path', path, false);
    
    -- Return success
    RETURN true;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Failed to set global hessra.public_key_path: %', SQLERRM;
        RETURN false;
END;
$$ LANGUAGE plpgsql STRICT;

-- Add more functions, types, operators etc. as needed 