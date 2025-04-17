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

# Make sure the script is executable
chmod +x test_token_verification.py

# Build and start the test environment
echo "Building and starting test environment..."
docker-compose -f docker-compose.test.yml down -v --remove-orphans
docker-compose -f docker-compose.test.yml build
docker-compose -f docker-compose.test.yml up --abort-on-container-exit

# Clean up
echo "Cleaning up..."
docker-compose -f docker-compose.test.yml down -v --remove-orphans

echo "Tests completed!" 