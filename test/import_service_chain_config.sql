-- Import script for Hessra test configuration
-- This script imports test data into the tables created by the extension

-- Make sure we're connected to the correct database
\c hessra_test

-- Start a transaction
BEGIN;

-- First, verify the tables exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'hessra_public_keys') THEN
        RAISE EXCEPTION 'Table hessra_public_keys does not exist. The extension must not be properly installed.';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'hessra_service_chains') THEN
        RAISE EXCEPTION 'Table hessra_service_chains does not exist. The extension must not be properly installed.';
    END IF;
END $$;

-- Clear existing data (optional, comment out if you want to preserve existing data)
TRUNCATE hessra_public_keys, hessra_service_chains;

-- Insert the main authorization service public key
INSERT INTO hessra_public_keys (key_name, public_key, description, is_default)
VALUES (
    'auth_service_key', 
    'ed25519/e57618058b1d2e0381a9813c1405830d5ed7d603717384ef555d9cc0cfa65d83', 
    'Main authorization service public key from test data',
    TRUE
);

-- Insert the order service chain configuration
INSERT INTO hessra_service_chains (service_name, service_chain, description)
VALUES (
    'order_service',
    '{
        "service_nodes": [
            {
                "component": "auth_service",
                "public_key": "ed25519/e57618058b1d2e0381a9813c1405830d5ed7d603717384ef555d9cc0cfa65d83"
            },
            {
                "component": "payment_service",
                "public_key": "ed25519/78ef4255c4c9ab5c7186d6db4760758b06616c042a2538323ae3b058094034b6"
            },
            {
                "component": "order_service",
                "public_key": "ed25519/1aebc5a6eefc569051926a6aaf55568e53edb475f2f2eb904522609391d88113"
            }
        ]
    }',
    'Service chain configuration for the order service from test data'
);

-- You can add more services here as needed

-- Commit the transaction
COMMIT;

-- Display the imported data for verification
SELECT * FROM hessra_public_keys;
SELECT * FROM hessra_service_chains;

-- Example usage of the verification function provided by the extension
SELECT verify_hessra_service_chain_by_name(
    'EtgDCuQCChZ1cmk6dXJuOnRlc3Q6YXJnby1jbGkxCg1vcmRlcl9zZXJ2aWNlCgFzCgxhdXRoX3NlcnZpY2UKD3BheW1lbnRfc2VydmljZRgEIhIKEAgEEgMYgAgSAxiBCBICGAAiEgoQCAQSAxiACBIDGIEIEgIYASobCgwIGBIDCIIIEgMYgwgSBwgMEgMIgggiAhAAKhsKDAgYEgMIgggSAxiECBIHCAwSAwiCCCICEAEqGwoMCBgSAwiCCBIDGIEIEgcIDBIDCIIIIgIQAjImCiQKAggbEgYIBRICCAUaFgoECgIIBQoICgYQ6I32nxIKBBoCCABCJAgAEiDldhgFix0uA4GpgTwUBYMNXtfWA3FzhO9VXZzAz6Zdg0IkCAASIHjvQlXEyatccYbW20dgdYsGYWwEKiU4MjrjsFgJQDS2QiQIABIgGuvFpu78VpBRkmpqr1VWjlPttHXy8uuQRSJgk5HYgRMSJAgAEiDW8Uj3Tu9N0Z0wC5OwPBwhjzxEQftCz1knQS/E1sIpkhpHMEUCIEsRzjbTnVTbSCYfIrVUSduXqqrjStFgLOGYrsZeI3YWAiEAn5MZE1FXgSXslykTdOXHUiBsMP1jOKobFBVIs2XmZSIoARryAQocCg1vcmRlcl9zZXJ2aWNlGAUiCQoHCAwSAxiACBIkCAASIK/wIdbxAoJ1XnLNUOyO5S20vgOPOiI/k/pavE8CU2qdGkBL4YXoJ0yFrRHuONSKh/Ru47FudXEmBDDU8ofHDRkX0SoJa2nk1QyyDtnPi1qzHV5JHDZU3dBzW5b2Nr/Y1roMImgKQLzkyr3ckbmCzUwE7UmYHb9rw9PHTshE7YV4ypkF6hXQY3PO/rOnbMPnPHuWCFdBMIFgxiZg+kuS6Csh/EIzoAQSJAgAEiDldhgFix0uA4GpgTwUBYMNXtfWA3FzhO9VXZzAz6ZdgygBGvIBChwKDW9yZGVyX3NlcnZpY2UYBSIJCgcIDBIDGIAIEiQIABIgLLELHP29dHw6u0l302Olh5k+Ydlf9WxkxFSzowJoOB0aQIlNjyKdv5+Yur+BfzpQ2hOSdu9MGfsORcq4RaN7P6UE6o3UfbVuLB1iXocBN6fKJ2gZV2MNcAgUAuFa8UfayQkiaApAphrKlxWwEFicT5fDJFRewv7Ivyd2Qn0FHTFGFcypRDf6b/843bijdQHACevTvUPVmTyOxA+cFn/Ev0NmXA7TAhIkCAASIHjvQlXEyatccYbW20dgdYsGYWwEKiU4MjrjsFgJQDS2KAEa8gEKHAoNb3JkZXJfc2VydmljZRgFIgkKBwgMEgMYgAgSJAgAEiBWo8hS30ACLAkavwQY4BdDRhI895SFpOuQHYvN8fGt+xpA21yQSK/6gHfOggNcygRoURvh1fFxL8VdMsvhpVq1Rj7KXG6rlp76iyn4cWOgmE2HbWWXYro/xPiIyYypbLaVCSJoCkBf2qQXi52zCbVM9RZdatjGZfvX5WbrvgerzZm1kYqwgvJaI8lYKUTvqYhzEIffOT0KUaBonSeyJx2UFmrW4uYJEiQIABIgGuvFpu78VpBRkmpqr1VWjlPttHXy8uuQRSJgk5HYgRMoASIiCiCbtGEhFUCCRhXwUllhWqL8wCy4kdrmIFJ+cudwXFaCcA==', -- token from service_chain_tokens.json
    'uri:urn:test:argo-cli1', -- subject
    'order_service', -- resource
    'order_service' -- component
) AS is_valid; 