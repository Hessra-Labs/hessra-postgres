-- Function to verify Hessra service chain token with mandatory service_nodes_json and component
CREATE FUNCTION verify_hessra_service_chain(token TEXT, subject TEXT, resource TEXT, service_nodes_json TEXT, component TEXT)
RETURNS BOOLEAN
AS '$libdir/hessra_authz', 'pg_verify_hessra_service_chain'
LANGUAGE C STRICT IMMUTABLE;

-- Helper function to verify service chain token in a more user-friendly way
CREATE OR REPLACE FUNCTION verify_hessra_service_chain_access(
    p_token TEXT,
    p_subject TEXT,
    p_resource TEXT, 
    p_service_nodes TEXT, -- JSON array of service nodes objects
    p_component TEXT      -- The component to check for in the chain
) RETURNS BOOLEAN AS $$
BEGIN
    RETURN verify_hessra_service_chain(
        p_token,
        p_subject, 
        p_resource,
        p_service_nodes,
        p_component
    );
END;
$$ LANGUAGE plpgsql; 