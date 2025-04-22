#!/usr/bin/env python3
"""
Test script for Hessra service chain token verification in PostgreSQL
"""
import json
import os
import psycopg2
import pytest
from typing import Dict, List, Any
from dataclasses import dataclass
import sys

# Configuration
DB_HOST = os.environ.get("DB_HOST", "localhost")
DB_PORT = os.environ.get("DB_PORT", "5432")
DB_NAME = os.environ.get("DB_NAME", "hessra_test")
DB_USER = os.environ.get("DB_USER", "postgres")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "mysecretpassword")

# Path to the service chain tokens file
TOKENS_FILE = os.path.join(os.path.dirname(__file__), "service_chain_tokens.json")

@dataclass
class ServiceChainToken:
    """Class to hold service chain token data"""
    name: str
    token: str
    subject: str
    resource: str
    description: str
    service_nodes: List[Dict[str, str]]
    token_type: str

def load_service_chain_tokens() -> List[ServiceChainToken]:
    """Load service chain tokens from JSON file"""
    with open(TOKENS_FILE, "r") as f:
        data = json.load(f)
    
    tokens = []
    for token_data in data["tokens"]:
        tokens.append(ServiceChainToken(
            name=token_data["name"],
            token=token_data["token"],
            subject=token_data["metadata"]["subject"],
            resource=token_data["metadata"]["resource"],
            description=token_data["metadata"]["description"],
            service_nodes=token_data["metadata"].get("service_nodes", []),
            token_type=token_data["metadata"].get("type", "unknown")
        ))
    return tokens

def get_db_connection():
    """Create a connection to the PostgreSQL database"""
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD
    )

def test_service_chain_verification():
    """Test service chain token verification"""
    tokens = load_service_chain_tokens()
    conn = get_db_connection()
    
    try:
        # First, check if the extension and service chain verification function are working
        with conn.cursor() as cur:
            try:
                # Check if the extension is installed
                cur.execute("SELECT extname FROM pg_extension WHERE extname = 'hessra_authz'")
                if cur.fetchone() is None:
                    print("ERROR: hessra_authz extension is not installed!")
                    sys.exit(1)
                print("✓ Extension hessra_authz is installed")
                
                # Check if the verify_hessra_service_chain function exists
                cur.execute("""
                    SELECT routine_name 
                    FROM information_schema.routines 
                    WHERE routine_name = 'verify_hessra_service_chain' 
                    AND routine_schema = 'public'
                """)
                if not cur.fetchone():
                    print("ERROR: verify_hessra_service_chain function not found!")
                    return
                print("✓ verify_hessra_service_chain function exists")
                
                # Check if the tables exist and have the expected data
                cur.execute("SELECT COUNT(*) FROM hessra_public_keys")
                key_count = cur.fetchone()[0]
                print(f"✓ hessra_public_keys table exists with {key_count} records")
                
                cur.execute("SELECT COUNT(*) FROM hessra_service_chains")
                chain_count = cur.fetchone()[0]
                print(f"✓ hessra_service_chains table exists with {chain_count} records")
                
                # Check if the new function exists
                cur.execute("""
                    SELECT routine_name 
                    FROM information_schema.routines 
                    WHERE routine_name = 'verify_hessra_service_chain_by_name' 
                    AND routine_schema = 'public'
                """)
                if not cur.fetchone():
                    print("ERROR: verify_hessra_service_chain_by_name function not found!")
                    return
                print("✓ verify_hessra_service_chain_by_name function exists")
            except Exception as e:
                print(f"ERROR during extension check: {e}")
                return

        with conn.cursor() as cur:
            # Test each token in order of the service chain
            for token in tokens:
                print(f"\n======= Testing: {token.name} =======")
                print(f"Description: {token.description}")
                print(f"Subject: {token.subject}")
                print(f"Resource: {token.resource}")
                print(f"Token Type: {token.token_type}")
                print(f"Service Nodes Chain Length: {len(token.service_nodes)}")
                
                # Skip singleton tokens for now (use them for comparison)
                if token.token_type == "singleton":
                    print("This is a singleton token, testing with basic verification...")
                    # Test with basic verification
                    cur.execute(
                        "SELECT verify_hessra_token(%s, %s, %s)",
                        (token.token, token.subject, token.resource)
                    )
                    result = cur.fetchone()[0]
                    print(f"Basic Verification Result: {result}")
                    continue
                
                # For service chain tokens, test with the database table approach
                
                # First, test with the final component (should succeed if chain is complete)
                component = "order_service"  # The final component in our chain
                
                print(f"Testing with component (using DB tables): {component}")
                cur.execute(
                    "SELECT verify_hessra_service_chain_by_name(%s, %s, %s, %s)",
                    (token.token, token.subject, token.resource, component)
                )
                result = cur.fetchone()[0]
                print(f"Service Chain Verification Result (using DB tables): {result}")
                expected = len(token.service_nodes) >= 3  # Should succeed only if all 3 nodes are in chain
                
                if result != expected:
                    print(f"‼️ SERVICE CHAIN VERIFICATION (using DB tables) FAILED: Expected {expected}, got {result}")
                    
                # For comparison, also test with the original method
                service_nodes_json = json.dumps({"service_nodes": token.service_nodes})
                
                print(f"Testing with component (using direct JSON): {component}")
                cur.execute(
                    "SELECT verify_hessra_service_chain(%s, %s, %s, %s, %s)",
                    (token.token, token.subject, token.resource, service_nodes_json, component)
                )
                direct_result = cur.fetchone()[0]
                print(f"Service Chain Verification Result (using direct JSON): {direct_result}")
                
                if result != direct_result:
                    print(f"‼️ DISCREPANCY BETWEEN METHODS: DB tables result: {result}, Direct JSON result: {direct_result}")
                
                # Now test with earlier components in the chain using the DB tables approach
                if len(token.service_nodes) > 0:
                    # Test with auth_service (should always succeed if present in chain)
                    component = "auth_service"
                    print(f"Testing with component (using DB tables): {component}")
                    cur.execute(
                        "SELECT verify_hessra_service_chain_by_name(%s, %s, %s, %s)",
                        (token.token, token.subject, token.resource, component)
                    )
                    result = cur.fetchone()[0]
                    print(f"Service Chain Verification for {component} Result (using DB tables): {result}")
                    
                    # Test with payment_service (should succeed if has at least 2 nodes)
                    if len(token.service_nodes) > 1:
                        component = "payment_service"
                        print(f"Testing with component (using DB tables): {component}")
                        cur.execute(
                            "SELECT verify_hessra_service_chain_by_name(%s, %s, %s, %s)",
                            (token.token, token.subject, token.resource, component)
                        )
                        result = cur.fetchone()[0]
                        print(f"Service Chain Verification for {component} Result (using DB tables): {result}")
                
                # Test with non-existent component (should fail)
                component = "nonexistent_service"
                print(f"Testing with non-existent component (using DB tables): {component}")
                cur.execute(
                    "SELECT verify_hessra_service_chain_by_name(%s, %s, %s, %s)",
                    (token.token, token.subject, token.resource, component)
                )
                result = cur.fetchone()[0]
                print(f"Service Chain Verification for non-existent component Result (using DB tables): {result}")
                assert result == False, f"Verification with non-existent component should fail"
                
                # Test the new function that uses the DB tables
                print("\nTesting access_service_with_chain_from_db function:")
                component = "order_service"
                try:
                    cur.execute(
                        "SELECT * FROM access_service_with_chain_from_db(%s, %s, %s, %s)",
                        (token.token, token.subject, token.resource, component)
                    )
                    service_result = cur.fetchone()
                    if service_result:
                        authorized = service_result[4]  # authorized is the 5th column
                        chain_verified = service_result[5]  # chain_verified is the 6th column
                        print(f"Service access result: authorized={authorized}, chain_verified={chain_verified}")
                    else:
                        print(f"Service not found: {token.resource}")
                except Exception as e:
                    print(f"Error testing access_service_with_chain_from_db: {e}")
    finally:
        conn.close()

def test_database_configuration():
    """Test that the database configuration is correctly set up"""
    conn = get_db_connection()
    
    try:
        with conn.cursor() as cur:
            # Check the public keys table
            cur.execute("SELECT key_name, public_key, is_default FROM hessra_public_keys")
            rows = cur.fetchall()
            print("\n===== Public Keys in Database =====")
            for row in rows:
                key_name, public_key, is_default = row
                print(f"Key: {key_name}, Public Key: {public_key[:30]}..., Default: {is_default}")
            
            # Check the service chains table
            cur.execute("SELECT service_name, service_chain FROM hessra_service_chains")
            rows = cur.fetchall()
            print("\n===== Service Chains in Database =====")
            for row in rows:
                service_name, service_chain = row
                # Parse the JSON to get the number of nodes
                chain_data = json.loads(service_chain) if isinstance(service_chain, str) else service_chain
                node_count = len(chain_data.get("service_nodes", []))
                print(f"Service: {service_name}, Chain Nodes: {node_count}")
                
                # Print each node in the chain
                for i, node in enumerate(chain_data.get("service_nodes", []), 1):
                    print(f"  Node {i}: {node.get('component')}, Key: {node.get('public_key')[:20]}...")
    finally:
        conn.close()

if __name__ == "__main__":
    print("Running Hessra service chain token verification tests...")
    
    # Run the tests
    try:
        test_database_configuration()
        test_service_chain_verification()
        print("\nService chain tests completed - check output for failures.")
    except Exception as e:
        print(f"\nError running tests: {e}") 