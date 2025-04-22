-- Create test database and extension
CREATE DATABASE hessra_test;
\c hessra_test

-- Create extension (make sure it's installed)
CREATE EXTENSION hessra_authz;

-- Verify extension is successfully installed (but don't try to fix anything if it's not)
DO $$
BEGIN
    -- Check if the extension is installed
    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'hessra_authz') THEN
        RAISE WARNING 'Extension hessra_authz does not appear to be installed correctly.';
    END IF;
END $$;

-- Create tables for test data
CREATE TABLE resources (
    id SERIAL PRIMARY KEY,
    resource_id TEXT NOT NULL UNIQUE,
    description TEXT NOT NULL,
    content TEXT NOT NULL,
    owner_id TEXT NOT NULL
);

-- Create service table for service chain testing
CREATE TABLE services (
    id SERIAL PRIMARY KEY,
    service_id TEXT NOT NULL UNIQUE,
    description TEXT NOT NULL,
    access_level TEXT NOT NULL
);

-- Insert sample data for resources
INSERT INTO resources (resource_id, description, content, owner_id) VALUES 
    ('resource1', 'Resource 1 data', 'Confidential resource 1 content', 'uri:urn:test:argo-cli0'),
    ('resource2', 'Resource 2 data', 'Confidential resource 2 content', 'uri:urn:test:argo-cli1'),
    ('resource3', 'Resource 3 data', 'Confidential resource 3 content', 'uri:urn:test:argo-cli1'),
    ('resource4', 'Resource 4 data', 'Confidential resource 4 content', 'uri:urn:test:argo-cli1');

-- Insert service data
INSERT INTO services (service_id, description, access_level) VALUES
    ('auth_service', 'Authentication Service', 'system'),
    ('payment_service', 'Payment Processing Service', 'system'),
    ('order_service', 'Order Management Service', 'user');

-- Create a function that uses the token verification for resources
CREATE OR REPLACE FUNCTION get_resource_if_authorized(
    p_token TEXT,
    p_subject TEXT,
    p_resource_id TEXT
) RETURNS TABLE (
    id INTEGER,
    resource_id TEXT,
    description TEXT,
    content TEXT,
    owner_id TEXT,
    authorized BOOLEAN
) AS $$
BEGIN
    -- Verify the token first
    IF verify_hessra_token(p_token, p_subject, p_resource_id) THEN
        RETURN QUERY
            SELECT r.id, r.resource_id, r.description, r.content, r.owner_id, TRUE
            FROM resources r
            WHERE r.resource_id = p_resource_id;
    ELSE
        -- Return the resource with NULL content to indicate unauthorized
        RETURN QUERY
            SELECT r.id, r.resource_id, r.description, NULL::TEXT, r.owner_id, FALSE
            FROM resources r
            WHERE r.resource_id = p_resource_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create a function that uses the token verification for services
CREATE OR REPLACE FUNCTION access_service_if_authorized(
    p_token TEXT,
    p_subject TEXT,
    p_service_id TEXT
) RETURNS TABLE (
    id INTEGER,
    service_id TEXT,
    description TEXT,
    access_level TEXT,
    authorized BOOLEAN
) AS $$
BEGIN
    -- Verify the token first
    IF verify_hessra_token(p_token, p_subject, p_service_id) THEN
        RETURN QUERY
            SELECT s.id, s.service_id, s.description, s.access_level, TRUE
            FROM services s
            WHERE s.service_id = p_service_id;
    ELSE
        -- Return the service with NULL access_level to indicate unauthorized
        RETURN QUERY
            SELECT s.id, s.service_id, s.description, NULL::TEXT, FALSE
            FROM services s
            WHERE s.service_id = p_service_id;
    END IF;
END;
$$ LANGUAGE plpgsql; 