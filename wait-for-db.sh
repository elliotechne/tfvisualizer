#!/bin/bash
# wait-for-db.sh
# Wait for PostgreSQL database to be ready before starting the application

set -e

# Use environment variables directly (DB_HOST, DB_PORT, etc. are set in Kubernetes secret)
# If not set, try parsing DATABASE_URL, then fall back to defaults
DB_HOST="${DB_HOST:-${POSTGRES_HOST}}"
DB_PORT="${DB_PORT:-${POSTGRES_PORT}}"
DB_USER="${DB_USER:-${POSTGRES_USER}}"
DB_PASSWORD="${DB_PASSWORD:-${POSTGRES_PASSWORD}}"
DB_NAME="${DB_NAME:-${POSTGRES_DB}}"

# If still not set and DATABASE_URL is available, parse it
if [ -z "$DB_HOST" ] && [ -n "$DATABASE_URL" ]; then
  # Extract host and port from DATABASE_URL
  # Format: postgresql://user:password@host:port/database
  DB_HOST=$(echo $DATABASE_URL | sed -E 's|.*@([^:]+):.*|\1|')
  DB_PORT=$(echo $DATABASE_URL | sed -E 's|.*:([0-9]+)/.*|\1|')
  DB_USER=$(echo $DATABASE_URL | sed -E 's|.*://([^:]+):.*|\1|')
  DB_PASSWORD=$(echo $DATABASE_URL | sed -E 's|.*://[^:]+:([^@]+)@.*|\1|')
  DB_NAME=$(echo $DATABASE_URL | sed -E 's|.*/([^?]+).*|\1|')
fi

# Final fallback to defaults
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-tfuser}"
DB_PASSWORD="${DB_PASSWORD:-tfpass}"
DB_NAME="${DB_NAME:-tfvisualizer}"

echo "Waiting for PostgreSQL at ${DB_HOST}:${DB_PORT}..."
echo "Debug: Testing connection parameters..."
echo "  Host: $DB_HOST"
echo "  Port: $DB_PORT"
echo "  User: $DB_USER"
echo "  Database: $DB_NAME"

# Wait for PostgreSQL to be ready (accepting connections)
for i in {1..60}; do
  # Use netcat to check if port is open
  if nc -z "$DB_HOST" "$DB_PORT" 2>/dev/null; then
    echo "PostgreSQL port is open!"

    # Now try to connect using psql
    if PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c '\q' 2>&1; then
      echo "Database '$DB_NAME' is ready!"

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
    else
      echo "Port open but psql connection failed - attempt $i/60"
    fi
  else
    echo "PostgreSQL is unavailable (port not open) - attempt $i/60"
  fi

  sleep 2
done

echo "ERROR: PostgreSQL did not become available in time"
exit 1
