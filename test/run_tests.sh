#!/bin/bash
set -e

# Script to run the Hessra PostgreSQL extension tests

echo "Running Hessra PostgreSQL Extension Tests"
echo "----------------------------------------"

# Check if docker and docker-compose are installed
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "Error: Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Check if the tokens file exists and has been populated
if [ ! -f "test_tokens.json" ]; then
    echo "Error: test_tokens.json not found. Please create this file with your test tokens."
    exit 1
fi

# Check if the service chain tokens file exists
if [ ! -f "service_chain_tokens.json" ]; then
    echo "Warning: service_chain_tokens.json not found. Service chain tests will be skipped."
    RUN_SERVICE_CHAIN_TESTS=false
else
    RUN_SERVICE_CHAIN_TESTS=true
fi

# Check if the order service chain file exists
if [ ! -f "order_service_chain.json" ]; then
    echo "Warning: order_service_chain.json not found. This file is needed for database table tests."
    RUN_DB_SERVICE_CHAIN_TESTS=false
else
    RUN_DB_SERVICE_CHAIN_TESTS=true
fi

# Make sure the scripts are executable
chmod +x test_token_verification.py
if [ "$RUN_SERVICE_CHAIN_TESTS" = true ]; then
    chmod +x test_service_chain.py
fi

# Clean up any existing containers
echo "Cleaning up any existing test containers..."
docker-compose -f docker-compose.test.yml down -v --remove-orphans

# Build and start the test environment
echo "Building and starting test environment..."
docker-compose -f docker-compose.test.yml build
docker-compose -f docker-compose.test.yml up -d postgres-test

# Wait for the PostgreSQL container to be healthy
echo "Waiting for PostgreSQL to be ready..."
for i in {1..30}; do
    if docker exec postgres-hessra-test pg_isready -U postgres; then
        echo "PostgreSQL is ready!"
        break
    fi
    echo "Waiting for PostgreSQL to be ready... ($i/30)"
    sleep 2
    if [ $i -eq 30 ]; then
        echo "Error: PostgreSQL did not become ready in time."
        docker-compose -f docker-compose.test.yml down -v --remove-orphans
        exit 1
    fi
done

# Run the smoke test to verify the extension is properly installed
echo ""
echo "Running Extension Smoke Test..."
echo "-----------------------------"
docker-compose -f docker-compose.test.yml exec -T postgres-test psql -U postgres -f /app/smoke_test.sql

# Check if the smoke test passed
if [ $? -ne 0 ]; then
    echo "❌ SMOKE TEST FAILED: The extension is not properly installed or is missing required components."
    echo "Please check the extension installation and try again."
    docker-compose -f docker-compose.test.yml down -v --remove-orphans
    exit 1
else
    echo "✅ SMOKE TEST PASSED: The extension is properly installed with all required components."
fi

# Run the basic token verification tests
echo ""
echo "Running basic token verification tests..."
docker-compose -f docker-compose.test.yml run --rm test-runner

# If we want to run service chain tests specifically
if [ "$RUN_SERVICE_CHAIN_TESTS" = true ]; then
    echo ""
    echo "Running Service Chain Tests..."
    echo "-----------------------------"
    docker-compose -f docker-compose.test.yml run --rm test-runner python test_service_chain.py
fi

# If we want to run database import tests
if [ "$RUN_DB_SERVICE_CHAIN_TESTS" = true ]; then
    echo ""
    echo "Running Database Table Configuration Test..."
    echo "-----------------------------------------"
    
    # Import the service chain configuration
    echo "Running import_service_chain_config.sql..."
    docker-compose -f docker-compose.test.yml exec -T postgres-test psql -U postgres -d hessra_test -f /app/import_service_chain_config.sql
    
    # Run the verification example
    echo ""
    echo "Testing service chain verification using database tables..."
    docker-compose -f docker-compose.test.yml exec -T postgres-test psql -U postgres -d hessra_test -f /app/verify_service_chain_example.sql
fi

# Clean up
echo ""
echo "Cleaning up..."
docker-compose -f docker-compose.test.yml down -v --remove-orphans

echo "Tests completed!" 