#!/bin/sh
# wait-for-db.sh - Wait for PostgreSQL to be ready before starting the application

set -e

host="$1"
port="${2:-5432}"

echo "=========================================="
echo "Waiting for PostgreSQL at $host:$port..."
echo "=========================================="

# Wait for port to be open
max_tries=60
tries=0

until nc -z "$host" "$port" 2>/dev/null; do
  tries=$((tries + 1))
  if [ $tries -ge $max_tries ]; then
    echo "ERROR: PostgreSQL port $host:$port is not reachable after $max_tries attempts"
    exit 1
  fi
  echo "PostgreSQL is unavailable - attempt $tries/$max_tries - sleeping 1s..."
  sleep 1
done

echo "PostgreSQL port is open - checking if it accepts connections..."

# Additional check to ensure PostgreSQL is not just listening but actually ready
tries=0
while [ $tries -lt 30 ]; do
  if PGPASSWORD="${DB_PASSWORD:-tfpass_dev_only}" psql -h "$host" -p "$port" -U "${DB_USER:-tfuser}" -d "${DB_NAME:-tfvisualizer}" -c "SELECT 1" > /dev/null 2>&1; then
    echo "=========================================="
    echo "✓ PostgreSQL is ready and accepting connections!"
    echo "=========================================="
    exit 0
  fi

  tries=$((tries + 1))
  echo "PostgreSQL is not ready yet (attempt $tries/30) - sleeping 1s..."
  sleep 1
done

echo "ERROR: PostgreSQL did not become ready in time"
exit 1
