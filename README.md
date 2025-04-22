# Hessra PostgreSQL Extension

A PostgreSQL extension that integrates with the Hessra token-based authorization system, providing token verification directly in the database.

https://www.hessra.net/ | hello@hessra.net

## Features

- Token verification as a PostgreSQL function
- Service Chain token verification for multi-service authentication flows
- Simple API for integrating with your PostgreSQL applications
- Efficient verification using Rust-based FFI library

## Token Verification Functions

### Basic Token Verification

```sql
SELECT verify_hessra_token(token, subject, resource);
```

- `token`: The Hessra token string
- `subject`: The subject (identity) attempting access
- `resource`: The resource being accessed

Returns: `boolean` indicating whether the token is valid and permits access.

### Service Chain Token Verification

```sql
SELECT verify_hessra_service_chain(token, subject, resource, service_nodes_json, component);
```

- `token`: The Hessra token string
- `subject`: The subject (identity) attempting access
- `resource`: The resource being accessed
- `service_nodes_json`: JSON array of service nodes the token must have been attenuated by
- `component`: The current component/service making the verification

Returns: `boolean` indicating whether the token is valid for the service chain.

## Installation

1. Build the extension
2. Install PostgreSQL extension
3. Create extension in your database:

```sql
CREATE EXTENSION hessra_authz;
```

## Configuration

The extension requires a Hessra public key for token verification. By default, it looks for the key at:

```
/etc/postgresql/hessra_key.pem
```

## Testing

Run the test suite to verify functionality:

```bash
cd test
./run_tests.sh
```

This tests both basic token verification and service chain token verification.

## License

This extension is licensed under Apache-2.0
