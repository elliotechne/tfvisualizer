#!/bin/bash

# Test the DATABASE_URL parsing logic from wait-for-db.sh

TEST_URL="postgresql://tfuser:TESTPASS@postgres.tfvisualizer.svc.cluster.local:5432/tfvisualizer"

echo "Testing DATABASE_URL parsing:"
echo "DATABASE_URL=$TEST_URL"
echo ""

# Extract components using the same sed commands from wait-for-db.sh
DB_HOST=$(echo $TEST_URL | sed -E 's/.*@([^:]+):.*/\1/')
DB_PORT=$(echo $TEST_URL | sed -E 's/.*:([0-9]+)\/.*/\1/')
DB_USER=$(echo $TEST_URL | sed -E 's/.*:\/\/([^:]+):.*/\1/')
DB_PASSWORD=$(echo $TEST_URL | sed -E 's/.*:\/\/[^:]+:([^@]+)@.*/\1/')
DB_NAME=$(echo $TEST_URL | sed -E 's/.*\/([^?]+).*/\1/')

echo "Parsed values:"
echo "  DB_HOST: '$DB_HOST'"
echo "  DB_PORT: '$DB_PORT'"
echo "  DB_USER: '$DB_USER'"
echo "  DB_PASSWORD: '$DB_PASSWORD'"
echo "  DB_NAME: '$DB_NAME'"
echo ""

# Check if any are empty or incorrect
if [ -z "$DB_HOST" ] || [ "$DB_HOST" = "$TEST_URL" ]; then
  echo "ERROR: DB_HOST parsing failed!"
fi

if [ -z "$DB_PORT" ] || [ "$DB_PORT" = "$TEST_URL" ]; then
  echo "ERROR: DB_PORT parsing failed!"
fi

if [ -z "$DB_USER" ] || [ "$DB_USER" = "$TEST_URL" ]; then
  echo "ERROR: DB_USER parsing failed!"
fi

if [ -z "$DB_PASSWORD" ] || [ "$DB_PASSWORD" = "$TEST_URL" ]; then
  echo "ERROR: DB_PASSWORD parsing failed!"
fi

if [ -z "$DB_NAME" ] || [ "$DB_NAME" = "$TEST_URL" ]; then
  echo "ERROR: DB_NAME parsing failed!"
fi
