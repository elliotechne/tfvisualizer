#!/bin/bash
# wait-for-db.sh
# Wait for PostgreSQL database to be ready before starting the application

set -e

# Parse database connection from DATABASE_URL or use individual components
if [ -n "$DATABASE_URL" ]; then
  # Extract host and port from DATABASE_URL
  # Format: postgresql://user:password@host:port/database
  DB_HOST=$(echo $DATABASE_URL | sed -E 's/.*@([^:]+):.*/\1/')
  DB_PORT=$(echo $DATABASE_URL | sed -E 's/.*:([0-9]+)\/.*/\1/')
  DB_USER=$(echo $DATABASE_URL | sed -E 's/.*:\/\/([^:]+):.*/\1/')
  DB_PASSWORD=$(echo $DATABASE_URL | sed -E 's/.*:\/\/[^:]+:([^@]+)@.*/\1/')
  DB_NAME=$(echo $DATABASE_URL | sed -E 's/.*\/([^?]+).*/\1/')
else
  # Use environment variables
  DB_HOST="${DB_HOST:-${POSTGRES_HOST:-localhost}}"
  DB_PORT="${DB_PORT:-${POSTGRES_PORT:-5432}}"
  DB_USER="${DB_USER:-${POSTGRES_USER:-tfuser}}"
  DB_PASSWORD="${DB_PASSWORD:-${POSTGRES_PASSWORD:-tfpass}}"
  DB_NAME="${DB_NAME:-${POSTGRES_DB:-tfvisualizer}}"
fi

echo "Waiting for PostgreSQL at ${DB_HOST}:${DB_PORT}..."

# Wait for PostgreSQL to be ready
for i in {1..60}; do
  if PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c '\q' 2>/dev/null; then
    echo "PostgreSQL is up and ready!"

    # Run database migrations if flask is available
    if command -v flask &> /dev/null; then
      echo "Running database migrations..."
      flask db upgrade || echo "Warning: Migration failed or no migrations to run"
    fi

    # Execute the main command (remaining arguments)
    if [ $# -gt 0 ]; then
      exec "$@"
    else
      exit 0
    fi
  fi

  echo "PostgreSQL is unavailable - attempt $i/60"
  sleep 1
done

echo "ERROR: PostgreSQL did not become available in time"
exit 1
