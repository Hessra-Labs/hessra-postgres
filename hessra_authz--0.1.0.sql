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

-- Add more functions, types, operators etc. as needed 