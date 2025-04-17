# Hessra PostgreSQL Extension Tests

This directory contains tests for the Hessra PostgreSQL extension token verification functionality.

## Overview

The test suite verifies that the Hessra token verification works as expected within PostgreSQL by:

1. Testing direct function calls to `verify_hessra_token()`
2. Testing resource access control using tokens
3. Testing service access with authorization tokens

## Test Setup

### Prerequisites

- Docker and Docker Compose
- Test tokens in the `test_tokens.json` file

### Components

- `test_tokens.json`: Contains test tokens and their metadata (subject, resource, expected results)
- `setup_test_db.sql`: SQL script to set up the test database and sample data
- `test_token_verification.py`: Python script that runs the verification tests
- `docker-compose.test.yml`: Docker Compose file for the test environment
- `Dockerfile.test`: Dockerfile for the test runner
- `run_tests.sh`: Shell script to run the tests

## Token Format

The `test_tokens.json` file uses the following format:

```json
{
  "tokens": [
    {
      "name": "argo-cli1_access_resource2",
      "token": "Ev4BCooBChZ1cmk6dXJuOnRlc3Q6YXJnby1jbGkxCglyZXNvdXJjZTIKB3N1YmplY3QYAyISChAIBBIDGIAIEgMYgQgSAhgAIhIKEAgEEgMYgAgSAxiBCBICGAEiCgoICIIIEgMYgAgyJgokCgIIGxIGCAUSAggFGhYKBAoCCAUKCAoGEJHy5Z8SCgQaAggAEiQIABIg5v4i6fEDlVByqSDcqpuo17pGrlt6KuGDiC+LCp5sTaoaRzBFAiBoPEIuy/VNeh9iLHiuB3v217/Jp/9A3JUHv0jjsjzPwgIhAI1sMoq6q/wzizVuZ1TLWMXvvT6AkPExTnBwzzxMuTXqKAEiIgogPBihP93tUj5jOTX7zTPOjAhFfJUPuvgVGOCADttUyZk=",
      "metadata": {
        "subject": "uri:urn:test:argo-cli1",
        "resource": "resource2",
        "description": "Valid token for argo-cli1 to access resource2",
        "expected_result": true
      }
    }
  ]
}
```

## Test Resources

The test resources in the database are:

1. Regular resources:

   - `resource1`: Owned by argo-cli0
   - `resource2`: Owned by argo-cli1
   - `resource3`: Owned by argo-cli1
   - `resource4`: Owned by argo-cli1

2. Services:
   - `auth_service`: Authentication service
   - `payment_service`: Payment processing service
   - `order_service`: Order management service

## How to Run Tests

1. Ensure `test_tokens.json` is populated with your test tokens
2. Run the tests with:

```bash
chmod +x run_tests.sh
./run_tests.sh
```

## Test Types

The test script performs three types of tests:

1. **Direct Token Verification**: Tests the `verify_hessra_token` function directly
2. **Resource Access**: Tests accessing resources with tokens using the `get_resource_if_authorized` function
3. **Service Access**: Tests accessing services with tokens using the `access_service_if_authorized` function

## Troubleshooting

If the tests fail:

1. Check that PostgreSQL is running with the extension installed
2. Verify your tokens are correctly formatted
3. Check that the public key (`hessra_key.pem`) matches the one used to sign the tokens
