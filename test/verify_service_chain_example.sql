-- Example of using service chain verification with the order_service_node_3_token
-- This is an example showing how to use the tables and functions 
-- with actual data from service_chain_tokens.json

-- Make sure we're connected to the correct database
\c hessra_test

-- First, check if extension tables exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'hessra_public_keys') THEN
        RAISE EXCEPTION 'Table hessra_public_keys does not exist. The extension must not be properly installed.';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'hessra_service_chains') THEN
        RAISE EXCEPTION 'Table hessra_service_chains does not exist. The extension must not be properly installed.';
    END IF;
END $$;

-- Check if we have data in our tables
SELECT COUNT(*) AS "Number of public keys" FROM hessra_public_keys;
SELECT COUNT(*) AS "Number of service chain configs" FROM hessra_service_chains;

-- Display all service chain configurations
SELECT service_name, service_chain FROM hessra_service_chains;

-- Example 1: Using verify_hessra_service_chain_by_name with the final order_service token
-- This verifies the token against the service chain stored in the database

SELECT verify_hessra_service_chain_by_name(
    -- Token from order_service_node_3_token in service_chain_tokens.json
    'EtgDCuQCChZ1cmk6dXJuOnRlc3Q6YXJnby1jbGkxCg1vcmRlcl9zZXJ2aWNlCgFzCgxhdXRoX3NlcnZpY2UKD3BheW1lbnRfc2VydmljZRgEIhIKEAgEEgMYgAgSAxiBCBICGAAiEgoQCAQSAxiACBIDGIEIEgIYASobCgwIGBIDCIIIEgMYgwgSBwgMEgMIgggiAhAAKhsKDAgYEgMIgggSAxiECBIHCAwSAwiCCCICEAEqGwoMCBgSAwiCCBIDGIEIEgcIDBIDCIIIIgIQAjImCiQKAggbEgYIBRICCAUaFgoECgIIBQoICgYQ6I32nxIKBBoCCABCJAgAEiDldhgFix0uA4GpgTwUBYMNXtfWA3FzhO9VXZzAz6Zdg0IkCAASIHjvQlXEyatccYbW20dgdYsGYWwEKiU4MjrjsFgJQDS2QiQIABIgGuvFpu78VpBRkmpqr1VWjlPttHXy8uuQRSJgk5HYgRMSJAgAEiDW8Uj3Tu9N0Z0wC5OwPBwhjzxEQftCz1knQS/E1sIpkhpHMEUCIEsRzjbTnVTbSCYfIrVUSduXqqrjStFgLOGYrsZeI3YWAiEAn5MZE1FXgSXslykTdOXHUiBsMP1jOKobFBVIs2XmZSIoARryAQocCg1vcmRlcl9zZXJ2aWNlGAUiCQoHCAwSAxiACBIkCAASIK/wIdbxAoJ1XnLNUOyO5S20vgOPOiI/k/pavE8CU2qdGkBL4YXoJ0yFrRHuONSKh/Ru47FudXEmBDDU8ofHDRkX0SoJa2nk1QyyDtnPi1qzHV5JHDZU3dBzW5b2Nr/Y1roMImgKQLzkyr3ckbmCzUwE7UmYHb9rw9PHTshE7YV4ypkF6hXQY3PO/rOnbMPnPHuWCFdBMIFgxiZg+kuS6Csh/EIzoAQSJAgAEiDldhgFix0uA4GpgTwUBYMNXtfWA3FzhO9VXZzAz6ZdgygBGvIBChwKDW9yZGVyX3NlcnZpY2UYBSIJCgcIDBIDGIAIEiQIABIgLLELHP29dHw6u0l302Olh5k+Ydlf9WxkxFSzowJoOB0aQIlNjyKdv5+Yur+BfzpQ2hOSdu9MGfsORcq4RaN7P6UE6o3UfbVuLB1iXocBN6fKJ2gZV2MNcAgUAuFa8UfayQkiaApAphrKlxWwEFicT5fDJFRewv7Ivyd2Qn0FHTFGFcypRDf6b/843bijdQHACevTvUPVmTyOxA+cFn/Ev0NmXA7TAhIkCAASIHjvQlXEyatccYbW20dgdYsGYWwEKiU4MjrjsFgJQDS2KAEa8gEKHAoNb3JkZXJfc2VydmljZRgFIgkKBwgMEgMYgAgSJAgAEiBWo8hS30ACLAkavwQY4BdDRhI895SFpOuQHYvN8fGt+xpA21yQSK/6gHfOggNcygRoURvh1fFxL8VdMsvhpVq1Rj7KXG6rlp76iyn4cWOgmE2HbWWXYro/xPiIyYypbLaVCSJoCkBf2qQXi52zCbVM9RZdatjGZfvX5WbrvgerzZm1kYqwgvJaI8lYKUTvqYhzEIffOT0KUaBonSeyJx2UFmrW4uYJEiQIABIgGuvFpu78VpBRkmpqr1VWjlPttHXy8uuQRSJgk5HYgRMoASIiCiCbtGEhFUCCRhXwUllhWqL8wCy4kdrmIFJ+cudwXFaCcA==',
    'uri:urn:test:argo-cli1',  -- subject
    'order_service',           -- resource
    'order_service'            -- component
) AS is_valid_for_order_service;

-- Example 2: Using the same token but verifying it at a different component in the chain
SELECT verify_hessra_service_chain_by_name(
    -- Same token as above
    'EtgDCuQCChZ1cmk6dXJuOnRlc3Q6YXJnby1jbGkxCg1vcmRlcl9zZXJ2aWNlCgFzCgxhdXRoX3NlcnZpY2UKD3BheW1lbnRfc2VydmljZRgEIhIKEAgEEgMYgAgSAxiBCBICGAAiEgoQCAQSAxiACBIDGIEIEgIYASobCgwIGBIDCIIIEgMYgwgSBwgMEgMIgggiAhAAKhsKDAgYEgMIgggSAxiECBIHCAwSAwiCCCICEAEqGwoMCBgSAwiCCBIDGIEIEgcIDBIDCIIIIgIQAjImCiQKAggbEgYIBRICCAUaFgoECgIIBQoICgYQ6I32nxIKBBoCCABCJAgAEiDldhgFix0uA4GpgTwUBYMNXtfWA3FzhO9VXZzAz6Zdg0IkCAASIHjvQlXEyatccYbW20dgdYsGYWwEKiU4MjrjsFgJQDS2QiQIABIgGuvFpu78VpBRkmpqr1VWjlPttHXy8uuQRSJgk5HYgRMSJAgAEiDW8Uj3Tu9N0Z0wC5OwPBwhjzxEQftCz1knQS/E1sIpkhpHMEUCIEsRzjbTnVTbSCYfIrVUSduXqqrjStFgLOGYrsZeI3YWAiEAn5MZE1FXgSXslykTdOXHUiBsMP1jOKobFBVIs2XmZSIoARryAQocCg1vcmRlcl9zZXJ2aWNlGAUiCQoHCAwSAxiACBIkCAASIK/wIdbxAoJ1XnLNUOyO5S20vgOPOiI/k/pavE8CU2qdGkBL4YXoJ0yFrRHuONSKh/Ru47FudXEmBDDU8ofHDRkX0SoJa2nk1QyyDtnPi1qzHV5JHDZU3dBzW5b2Nr/Y1roMImgKQLzkyr3ckbmCzUwE7UmYHb9rw9PHTshE7YV4ypkF6hXQY3PO/rOnbMPnPHuWCFdBMIFgxiZg+kuS6Csh/EIzoAQSJAgAEiDldhgFix0uA4GpgTwUBYMNXtfWA3FzhO9VXZzAz6ZdgygBGvIBChwKDW9yZGVyX3NlcnZpY2UYBSIJCgcIDBIDGIAIEiQIABIgLLELHP29dHw6u0l302Olh5k+Ydlf9WxkxFSzowJoOB0aQIlNjyKdv5+Yur+BfzpQ2hOSdu9MGfsORcq4RaN7P6UE6o3UfbVuLB1iXocBN6fKJ2gZV2MNcAgUAuFa8UfayQkiaApAphrKlxWwEFicT5fDJFRewv7Ivyd2Qn0FHTFGFcypRDf6b/843bijdQHACevTvUPVmTyOxA+cFn/Ev0NmXA7TAhIkCAASIHjvQlXEyatccYbW20dgdYsGYWwEKiU4MjrjsFgJQDS2KAEa8gEKHAoNb3JkZXJfc2VydmljZRgFIgkKBwgMEgMYgAgSJAgAEiBWo8hS30ACLAkavwQY4BdDRhI895SFpOuQHYvN8fGt+xpA21yQSK/6gHfOggNcygRoURvh1fFxL8VdMsvhpVq1Rj7KXG6rlp76iyn4cWOgmE2HbWWXYro/xPiIyYypbLaVCSJoCkBf2qQXi52zCbVM9RZdatjGZfvX5WbrvgerzZm1kYqwgvJaI8lYKUTvqYhzEIffOT0KUaBonSeyJx2UFmrW4uYJEiQIABIgGuvFpu78VpBRkmpqr1VWjlPttHXy8uuQRSJgk5HYgRMoASIiCiCbtGEhFUCCRhXwUllhWqL8wCy4kdrmIFJ+cudwXFaCcA==',
    'uri:urn:test:argo-cli1',  -- subject
    'order_service',           -- resource
    'payment_service'          -- component
) AS is_valid_for_payment_service;

-- Example 3: Using the direct C function with manually provided JSON
-- This approach gives you more flexibility but requires constructing the JSON manually
SELECT verify_hessra_service_chain(
    -- Same token as above
    'EtgDCuQCChZ1cmk6dXJuOnRlc3Q6YXJnby1jbGkxCg1vcmRlcl9zZXJ2aWNlCgFzCgxhdXRoX3NlcnZpY2UKD3BheW1lbnRfc2VydmljZRgEIhIKEAgEEgMYgAgSAxiBCBICGAAiEgoQCAQSAxiACBIDGIEIEgIYASobCgwIGBIDCIIIEgMYgwgSBwgMEgMIgggiAhAAKhsKDAgYEgMIgggSAxiECBIHCAwSAwiCCCICEAEqGwoMCBgSAwiCCBIDGIEIEgcIDBIDCIIIIgIQAjImCiQKAggbEgYIBRICCAUaFgoECgIIBQoICgYQ6I32nxIKBBoCCABCJAgAEiDldhgFix0uA4GpgTwUBYMNXtfWA3FzhO9VXZzAz6Zdg0IkCAASIHjvQlXEyatccYbW20dgdYsGYWwEKiU4MjrjsFgJQDS2QiQIABIgGuvFpu78VpBRkmpqr1VWjlPttHXy8uuQRSJgk5HYgRMSJAgAEiDW8Uj3Tu9N0Z0wC5OwPBwhjzxEQftCz1knQS/E1sIpkhpHMEUCIEsRzjbTnVTbSCYfIrVUSduXqqrjStFgLOGYrsZeI3YWAiEAn5MZE1FXgSXslykTdOXHUiBsMP1jOKobFBVIs2XmZSIoARryAQocCg1vcmRlcl9zZXJ2aWNlGAUiCQoHCAwSAxiACBIkCAASIK/wIdbxAoJ1XnLNUOyO5S20vgOPOiI/k/pavE8CU2qdGkBL4YXoJ0yFrRHuONSKh/Ru47FudXEmBDDU8ofHDRkX0SoJa2nk1QyyDtnPi1qzHV5JHDZU3dBzW5b2Nr/Y1roMImgKQLzkyr3ckbmCzUwE7UmYHb9rw9PHTshE7YV4ypkF6hXQY3PO/rOnbMPnPHuWCFdBMIFgxiZg+kuS6Csh/EIzoAQSJAgAEiDldhgFix0uA4GpgTwUBYMNXtfWA3FzhO9VXZzAz6ZdgygBGvIBChwKDW9yZGVyX3NlcnZpY2UYBSIJCgcIDBIDGIAIEiQIABIgLLELHP29dHw6u0l302Olh5k+Ydlf9WxkxFSzowJoOB0aQIlNjyKdv5+Yur+BfzpQ2hOSdu9MGfsORcq4RaN7P6UE6o3UfbVuLB1iXocBN6fKJ2gZV2MNcAgUAuFa8UfayQkiaApAphrKlxWwEFicT5fDJFRewv7Ivyd2Qn0FHTFGFcypRDf6b/843bijdQHACevTvUPVmTyOxA+cFn/Ev0NmXA7TAhIkCAASIHjvQlXEyatccYbW20dgdYsGYWwEKiU4MjrjsFgJQDS2KAEa8gEKHAoNb3JkZXJfc2VydmljZRgFIgkKBwgMEgMYgAgSJAgAEiBWo8hS30ACLAkavwQY4BdDRhI895SFpOuQHYvN8fGt+xpA21yQSK/6gHfOggNcygRoURvh1fFxL8VdMsvhpVq1Rj7KXG6rlp76iyn4cWOgmE2HbWWXYro/xPiIyYypbLaVCSJoCkBf2qQXi52zCbVM9RZdatjGZfvX5WbrvgerzZm1kYqwgvJaI8lYKUTvqYhzEIffOT0KUaBonSeyJx2UFmrW4uYJEiQIABIgGuvFpu78VpBRkmpqr1VWjlPttHXy8uuQRSJgk5HYgRMoASIiCiCbtGEhFUCCRhXwUllhWqL8wCy4kdrmIFJ+cudwXFaCcA==',
    'uri:urn:test:argo-cli1',  -- subject
    'order_service',           -- resource
    -- Service chain JSON directly from service_chain_tokens.json
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
    'auth_service'            -- component
) AS is_valid_for_auth_service; 