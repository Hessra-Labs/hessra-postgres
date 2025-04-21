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

# Make sure the scripts are executable
chmod +x test_token_verification.py
if [ "$RUN_SERVICE_CHAIN_TESTS" = true ]; then
    chmod +x test_service_chain.py
fi

# Build and start the test environment
echo "Building and starting test environment..."
docker-compose -f docker-compose.test.yml down -v --remove-orphans
docker-compose -f docker-compose.test.yml build
docker-compose -f docker-compose.test.yml up --abort-on-container-exit

# If we want to run service chain tests specifically
if [ "$RUN_SERVICE_CHAIN_TESTS" = true ]; then
    echo ""
    echo "Running Service Chain Tests..."
    echo "-----------------------------"
    docker-compose -f docker-compose.test.yml run --rm test-runner python test_service_chain.py
fi

# Clean up
echo "Cleaning up..."
docker-compose -f docker-compose.test.yml down -v --remove-orphans

echo "Tests completed!" 