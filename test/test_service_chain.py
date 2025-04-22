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
                
                # For service chain tokens, test with each component
                # Convert service_nodes to JSON for the function
                service_nodes_json = json.dumps(token.service_nodes)
                
                # First, test with the final component (should succeed if chain is complete)
                component = "order_service"  # The final component in our chain
                
                print(f"Testing with component: {component}")
                cur.execute(
                    "SELECT verify_hessra_service_chain(%s, %s, %s, %s, %s)",
                    (token.token, token.subject, token.resource, service_nodes_json, component)
                )
                result = cur.fetchone()[0]
                print(f"Service Chain Verification Result: {result}")
                expected = len(token.service_nodes) >= 3  # Should succeed only if all 3 nodes are in chain
                
                if result != expected:
                    print(f"‼️ SERVICE CHAIN VERIFICATION FAILED: Expected {expected}, got {result}")
                    
                # Now test with earlier components in the chain
                if len(token.service_nodes) > 0:
                    # Test with auth_service (should always succeed if present in chain)
                    component = "auth_service"
                    print(f"Testing with component: {component}")
                    cur.execute(
                        "SELECT verify_hessra_service_chain(%s, %s, %s, %s, %s)",
                        (token.token, token.subject, token.resource, service_nodes_json, component)
                    )
                    result = cur.fetchone()[0]
                    print(f"Service Chain Verification for {component} Result: {result}")
                    
                    # Test with payment_service (should succeed if has at least 2 nodes)
                    if len(token.service_nodes) > 1:
                        component = "payment_service"
                        print(f"Testing with component: {component}")
                        cur.execute(
                            "SELECT verify_hessra_service_chain(%s, %s, %s, %s, %s)",
                            (token.token, token.subject, token.resource, service_nodes_json, component)
                        )
                        result = cur.fetchone()[0]
                        print(f"Service Chain Verification for {component} Result: {result}")
                
                # Test with non-existent component (should fail)
                component = "nonexistent_service"
                print(f"Testing with non-existent component: {component}")
                cur.execute(
                    "SELECT verify_hessra_service_chain(%s, %s, %s, %s, %s)",
                    (token.token, token.subject, token.resource, service_nodes_json, component)
                )
                result = cur.fetchone()[0]
                print(f"Service Chain Verification for non-existent component Result: {result}")
                assert result == False, f"Verification with non-existent component should fail"
    finally:
        conn.close()

if __name__ == "__main__":
    print("Running Hessra service chain token verification tests...")
    
    # Run the tests
    try:
        test_service_chain_verification()
        print("\nService chain tests completed - check output for failures.")
    except Exception as e:
        print(f"\nError running tests: {e}") 