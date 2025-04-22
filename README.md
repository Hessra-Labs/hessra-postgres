# Hessra PostgreSQL Extension

A PostgreSQL extension that integrates with the Hessra token-based authorization system, providing token verification directly in the database.

https://www.hessra.net/ | hello@hessra.net

## Features

- Local biscuit-based token verification as a PostgreSQL function
- Service Chain token verification for multi-service authorization
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
- `service_nodes_json`: JSON array of service nodes the token must have 3rd party blocks added by
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

### Public Key Configuration

The extension requires a Hessra public key for token verification. There are several ways to configure the path to this key:

#### Default Path

By default, the extension looks for the key at:

```
/etc/postgresql/hessra_key.pem
```

#### Using PostgreSQL Configuration

You can specify a custom path through PostgreSQL configuration. The following options are available:

1. For the current session only:

```sql
-- Set the key path for the current session
SELECT set_hessra_public_key_path('/path/to/your/key.pem');
```

2. For all sessions (requires superuser):

```sql
-- Set the key path globally (persists across restarts)
SELECT set_hessra_public_key_path_global('/path/to/your/key.pem');
```

3. Direct configuration (advanced):

```sql
-- Set for current session only
SET hessra.public_key_path = '/path/to/your/key.pem';

-- Set globally (requires superuser, persists across restarts)
ALTER SYSTEM SET hessra.public_key_path = '/path/to/your/key.pem';
SELECT pg_reload_conf();
```

#### Using with Tembo PostgreSQL

When using this extension with Tembo PostgreSQL:

1. Use the Tembo UI to upload your public key to the PostgreSQL server
2. Set the path to the uploaded key using one of the configuration methods above
3. For the specific location of uploaded files in Tembo, refer to Tembo's documentation or contact Tembo support

## Row Level Security Integration

This extension can be used to implement Row Level Security (RLS) policies in PostgreSQL. Here's an example:

```sql
-- Enable RLS on your table
ALTER TABLE my_documents ENABLE ROW LEVEL SECURITY;

-- Create a policy that uses token verification
CREATE POLICY doc_access ON my_documents
FOR SELECT
USING (
  verify_hessra_token(
    current_setting('app.current_token', true), -- Token from your application
    current_user,                              -- Current database user
    'my_documents:read'                        -- Resource identifier
  )
);
```

In your application, you would set the token for the current session:

```sql
SET app.current_token = 'your-hessra-token-here';
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
