#!/usr/bin/env python3
"""
Test script for Hessra token verification in PostgreSQL
"""
import json
import os
import psycopg2
import pytest
from typing import Dict, List, Any
from dataclasses import dataclass

# Configuration
DB_HOST = os.environ.get("DB_HOST", "localhost")
DB_PORT = os.environ.get("DB_PORT", "5432")
DB_NAME = os.environ.get("DB_NAME", "hessra_test")
DB_USER = os.environ.get("DB_USER", "postgres")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "mysecretpassword")

# Path to the test tokens file
TOKENS_FILE = os.path.join(os.path.dirname(__file__), "test_tokens.json")

@dataclass
class TestToken:
    """Class to hold test token data"""
    name: str
    token: str
    subject: str
    resource: str
    description: str
    expected_result: bool

def load_test_tokens() -> List[TestToken]:
    """Load test tokens from JSON file"""
    with open(TOKENS_FILE, "r") as f:
        data = json.load(f)
    
    tokens = []
    for token_data in data["tokens"]:
        tokens.append(TestToken(
            name=token_data["name"],
            token=token_data["token"],
            subject=token_data["metadata"]["subject"],
            resource=token_data["metadata"]["resource"],
            description=token_data["metadata"]["description"],
            expected_result=token_data["metadata"]["expected_result"]
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

def test_direct_token_verification():
    """Test token verification directly using the PostgreSQL function"""
    tokens = load_test_tokens()
    conn = get_db_connection()
    
    try:
        with conn.cursor() as cur:
            for token in tokens:
                print(f"Testing: {token.name} - {token.description}")
                # Test direct verification
                cur.execute(
                    "SELECT verify_hessra_token(%s, %s, %s)",
                    (token.token, token.subject, token.resource)
                )
                result = cur.fetchone()[0]
                
                # Assert the result matches expected
                assert result == token.expected_result, \
                    f"Token {token.name} ({token.description}): Expected {token.expected_result}, got {result}"
                
                print(f"✓ Token test passed: {token.name} - {token.description}")
    finally:
        conn.close()

def test_resource_access():
    """Test resource access with token verification"""
    tokens = load_test_tokens()
    conn = get_db_connection()
    
    try:
        with conn.cursor() as cur:
            for token in tokens:
                # Skip tokens for service access
                if token.resource in ['auth_service', 'payment_service', 'order_service']:
                    continue
                
                # Try to access resource with the token
                print(f"Testing resource access: {token.name} - {token.resource}")
                cur.execute(
                    "SELECT * FROM get_resource_if_authorized(%s, %s, %s)",
                    (token.token, token.subject, token.resource)
                )
                result = cur.fetchone()
                
                if result:
                    authorized = result[5]  # authorized is the 6th column
                    
                    # Assert the authorization result matches expected
                    assert authorized == token.expected_result, \
                        f"Resource access with token {token.name}: Expected {token.expected_result}, got {authorized}"
                    
                    # If it should be authorized, content should not be NULL
                    if token.expected_result:
                        assert result[3] is not None, \
                            f"Resource content should be accessible with authorized token {token.name}"
                    # If it should not be authorized, content should be NULL
                    else:
                        assert result[3] is None, \
                            f"Resource content should not be accessible with unauthorized token {token.name}"
                    
                    print(f"✓ Resource access test passed: {token.name} - {token.description}")
                else:
                    # If no result, it could be a non-existent resource
                    print(f"! Resource not found: {token.resource}")
    finally:
        conn.close()

def test_service_access():
    """Test service access with token verification"""
    tokens = load_test_tokens()
    conn = get_db_connection()
    
    try:
        with conn.cursor() as cur:
            for token in tokens:
                # Only process tokens for service access
                if token.resource not in ['auth_service', 'payment_service', 'order_service']:
                    continue
                
                # Try to access service with the token
                print(f"Testing service access: {token.name} - {token.resource}")
                cur.execute(
                    "SELECT * FROM access_service_if_authorized(%s, %s, %s)",
                    (token.token, token.subject, token.resource)
                )
                result = cur.fetchone()
                
                if result:
                    authorized = result[4]  # authorized is the 5th column
                    
                    # Assert the authorization result matches expected
                    assert authorized == token.expected_result, \
                        f"Service access with token {token.name}: Expected {token.expected_result}, got {authorized}"
                    
                    # If it should be authorized, access_level should not be NULL
                    if token.expected_result:
                        assert result[3] is not None, \
                            f"Service access_level should be accessible with authorized token {token.name}"
                    # If it should not be authorized, access_level should be NULL
                    else:
                        assert result[3] is None, \
                            f"Service access_level should not be accessible with unauthorized token {token.name}"
                    
                    print(f"✓ Service access test passed: {token.name} - {token.description}")
                else:
                    # If no result, it could be a non-existent service
                    print(f"! Service not found: {token.resource}")
    finally:
        conn.close()

if __name__ == "__main__":
    print("Running Hessra token verification tests...")
    
    # Run the tests
    try:
        test_direct_token_verification()
        print("\n--- Resource Access Tests ---")
        test_resource_access()
        print("\n--- Service Access Tests ---")
        test_service_access()
        print("\nAll tests passed! ✓")
    except AssertionError as e:
        print(f"\nTest failed: {e}")
    except Exception as e:
        print(f"\nError running tests: {e}") 