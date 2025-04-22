-- This script sets up and tests the service chain verification in the PostgreSQL extension
-- It only relies on what the extension provides and doesn't create any tables

-- First, make sure we're connected to the correct database
\c hessra_test

-- Create a function to test service chain access to services using the database tables
CREATE OR REPLACE FUNCTION access_service_with_chain_from_db(
    p_token TEXT,
    p_subject TEXT,
    p_service_id TEXT,
    p_component TEXT,            -- The component to verify in the chain
    p_service_chain_json TEXT    -- The JSON data to use if not found in the database
) RETURNS TABLE (
    id INTEGER,
    service_id TEXT,
    description TEXT,
    access_level TEXT,
    authorized BOOLEAN,
    chain_verified BOOLEAN
) AS $$
DECLARE
    chain_valid BOOLEAN;
    service_nodes_json TEXT;
BEGIN
    -- First try to get the service chain from the database if the tables exist
    BEGIN
        IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'hessra_service_chains') THEN
            SELECT service_chain::TEXT INTO service_nodes_json 
            FROM hessra_service_chains 
            WHERE service_name = p_service_id;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            -- If anything goes wrong, just use the provided JSON
            service_nodes_json := NULL;
    END;
    
    -- If not found in the database, use the provided JSON
    IF service_nodes_json IS NULL THEN
        service_nodes_json := p_service_chain_json;
    END IF;
    
    -- Call the C function with the JSON data we have
    chain_valid := verify_hessra_service_chain(
        p_token, 
        p_subject, 
        p_service_id, 
        service_nodes_json, 
        p_component
    );
    
    IF chain_valid THEN
        -- If chain verification passes, return full service information
        RETURN QUERY
            SELECT s.id, s.service_id, s.description, s.access_level, TRUE, TRUE
            FROM services s
            WHERE s.service_id = p_service_id;
    ELSE
        -- If chain verification fails, try basic verification
        IF verify_hessra_token(p_token, p_subject, p_service_id) THEN
            -- Basic verification passed, but chain verification failed
            RETURN QUERY
                SELECT s.id, s.service_id, s.description, s.access_level, TRUE, FALSE
                FROM services s
                WHERE s.service_id = p_service_id;
        ELSE
            -- Both verifications failed
            RETURN QUERY
                SELECT s.id, s.service_id, s.description, NULL::TEXT, FALSE, FALSE
                FROM services s
                WHERE s.service_id = p_service_id;
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Keep the original function for comparison
CREATE OR REPLACE FUNCTION access_service_with_chain(
    p_token TEXT,
    p_subject TEXT,
    p_service_id TEXT,
    p_service_nodes_json TEXT,  -- JSON array of service nodes
    p_component TEXT            -- The component to verify in the chain
) RETURNS TABLE (
    id INTEGER,
    service_id TEXT,
    description TEXT,
    access_level TEXT,
    authorized BOOLEAN,
    chain_verified BOOLEAN
) AS $$
BEGIN
    -- First check if the token passes service chain verification
    DECLARE
        chain_valid BOOLEAN;
    BEGIN
        chain_valid := verify_hessra_service_chain(
            p_token, 
            p_subject, 
            p_service_id, 
            p_service_nodes_json,
            p_component
        );
    
        IF chain_valid THEN
            -- If chain verification passes, return full service information
            RETURN QUERY
                SELECT s.id, s.service_id, s.description, s.access_level, TRUE, TRUE
                FROM services s
                WHERE s.service_id = p_service_id;
        ELSE
            -- If chain verification fails, try basic verification
            IF verify_hessra_token(p_token, p_subject, p_service_id) THEN
                -- Basic verification passed, but chain verification failed
                RETURN QUERY
                    SELECT s.id, s.service_id, s.description, s.access_level, TRUE, FALSE
                    FROM services s
                    WHERE s.service_id = p_service_id;
            ELSE
                -- Both verifications failed
                RETURN QUERY
                    SELECT s.id, s.service_id, s.description, NULL::TEXT, FALSE, FALSE
                    FROM services s
                    WHERE s.service_id = p_service_id;
            END IF;
        END IF;
    END;
END;
$$ LANGUAGE plpgsql;

-- Create a view with the service chain components for easier testing
CREATE OR REPLACE VIEW service_chain_components AS
SELECT 
    'auth_service' AS component,
    1 AS position,
    'ed25519/e57618058b1d2e0381a9813c1405830d5ed7d603717384ef555d9cc0cfa65d83' AS public_key
UNION ALL
SELECT 
    'payment_service' AS component,
    2 AS position,
    'ed25519/78ef4255c4c9ab5c7186d6db4760758b06616c042a2538323ae3b058094034b6' AS public_key
UNION ALL
SELECT 
    'order_service' AS component,
    3 AS position,
    'ed25519/1aebc5a6eefc569051926a6aaf55568e53edb475f2f2eb904522609391d88113' AS public_key; 