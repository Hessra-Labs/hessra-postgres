---
-- SQL definitions for the postgres-plugin extension
---

-- Protect against nesting or direct execution
\echo Use "CREATE EXTENSION hessra_pg" to load this file. \quit

-- Function to verify Hessra token with mandatory subject and resource
CREATE FUNCTION verify_hessra_token(token TEXT, subject TEXT, resource TEXT)
RETURNS BOOLEAN
AS '$libdir/hessra_pg', 'pg_verify_hessra_token'
LANGUAGE C STRICT IMMUTABLE;

-- Add more functions, types, operators etc. as needed 