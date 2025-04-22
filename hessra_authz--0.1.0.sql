---
-- SQL definitions for the postgres-plugin extension
---

-- Protect against nesting or direct execution
\echo Use "CREATE EXTENSION hessra_authz" to load this file. \quit

-- Create tables for Hessra configuration

-- Table to store the main authorization service public key
CREATE TABLE IF NOT EXISTS hessra_public_keys (
    id SERIAL PRIMARY KEY,
    key_name TEXT NOT NULL UNIQUE,
    public_key TEXT NOT NULL,
    description TEXT,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Ensure only one default key
CREATE OR REPLACE FUNCTION update_default_public_key() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_default THEN
        UPDATE hessra_public_keys SET is_default = FALSE WHERE id != NEW.id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_default_public_key
BEFORE INSERT OR UPDATE ON hessra_public_keys
FOR EACH ROW
WHEN (NEW.is_default)
EXECUTE FUNCTION update_default_public_key();

-- Table to store service chain configurations
CREATE TABLE IF NOT EXISTS hessra_service_chains (
    id SERIAL PRIMARY KEY,
    service_name TEXT NOT NULL UNIQUE,
    service_chain JSONB NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

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

-- Function to get the service chain JSON for a specific service
CREATE OR REPLACE FUNCTION get_service_chain_json(service TEXT) 
RETURNS TEXT AS $$
DECLARE
    chain_json TEXT;
BEGIN
    SELECT service_chain::TEXT INTO chain_json 
    FROM hessra_service_chains 
    WHERE service_name = service;
    
    RETURN chain_json;
END;
$$ LANGUAGE plpgsql STRICT;

-- Function to verify a service chain token using the stored configuration
CREATE OR REPLACE FUNCTION verify_hessra_service_chain_by_name(
    token TEXT, 
    subject TEXT, 
    resource TEXT, 
    component TEXT
) RETURNS BOOLEAN AS $$
DECLARE
    service_nodes_json TEXT;
BEGIN
    -- Get the service chain JSON for the resource
    SELECT service_chain::TEXT INTO service_nodes_json 
    FROM hessra_service_chains 
    WHERE service_name = resource;
    
    IF service_nodes_json IS NULL THEN
        RAISE WARNING 'No service chain configuration found for service: %', resource;
        RETURN FALSE;
    END IF;
    
    -- Call the C function with the retrieved JSON
    RETURN verify_hessra_service_chain(
        token, 
        subject, 
        resource, 
        service_nodes_json, 
        component
    );
END;
$$ LANGUAGE plpgsql STRICT;

-- Helper functions for managing configuration tables

-- Function to set the default public key
CREATE OR REPLACE FUNCTION set_default_public_key(key_name_param TEXT) 
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE hessra_public_keys SET is_default = TRUE WHERE key_name = key_name_param;
    
    IF NOT FOUND THEN
        RAISE WARNING 'Public key with name "%" not found', key_name_param;
        RETURN FALSE;
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql STRICT;

-- Function to get the default public key
CREATE OR REPLACE FUNCTION get_default_public_key() 
RETURNS TEXT AS $$
DECLARE
    key_value TEXT;
BEGIN
    SELECT public_key INTO key_value FROM hessra_public_keys WHERE is_default = TRUE LIMIT 1;
    
    IF key_value IS NULL THEN
        RAISE WARNING 'No default public key set';
        RETURN NULL;
    END IF;
    
    RETURN key_value;
END;
$$ LANGUAGE plpgsql STRICT;

-- Function to add or update a service chain configuration
CREATE OR REPLACE FUNCTION upsert_service_chain(
    service_name_param TEXT,
    service_chain_json JSONB,
    description_param TEXT DEFAULT NULL
) RETURNS BOOLEAN AS $$
BEGIN
    INSERT INTO hessra_service_chains (service_name, service_chain, description)
    VALUES (service_name_param, service_chain_json, description_param)
    ON CONFLICT (service_name) 
    DO UPDATE SET 
        service_chain = service_chain_json,
        description = COALESCE(description_param, hessra_service_chains.description),
        updated_at = CURRENT_TIMESTAMP;
    
    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Failed to upsert service chain: %', SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql STRICT;

-- Function to verify a token using the default public key
CREATE OR REPLACE FUNCTION verify_hessra_token_default(token TEXT, subject TEXT, resource TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    default_key TEXT;
    key_path TEXT;
    result BOOLEAN;
BEGIN
    -- First try to get key from the database
    SELECT public_key INTO default_key FROM hessra_public_keys WHERE is_default = TRUE LIMIT 1;
    
    IF default_key IS NOT NULL THEN
        -- Write key to temporary file
        key_path := '/tmp/hessra_temp_key_' || md5(random()::text) || '.pem';
        PERFORM pg_catalog.pg_file_write(key_path, default_key, false);
        
        -- Set path for verification
        PERFORM set_hessra_public_key_path(key_path);
        
        -- Verify token
        result := verify_hessra_token(token, subject, resource);
        
        -- Clean up temp file
        PERFORM pg_catalog.pg_file_unlink(key_path);
        
        RETURN result;
    ELSE
        -- Fall back to configured key path
        RETURN verify_hessra_token(token, subject, resource);
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error in verify_hessra_token_default: %', SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql STRICT;

-- Add more functions, types, operators etc. as needed 