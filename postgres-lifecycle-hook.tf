# Add this to the PostgreSQL container in databases.tf

# Inside the postgres container spec, add:
lifecycle {
  post_start {
    exec {
      command = [
        "/bin/sh",
        "-c",
        <<-EOT
          # Wait a bit for PostgreSQL to be fully ready
          sleep 10

          # Create root role
          psql -v ON_ERROR_STOP=0 -U tfuser -d tfvisualizer <<-EOSQL
            DO \$\$
            BEGIN
              IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'root') THEN
                CREATE ROLE root WITH SUPERUSER LOGIN PASSWORD '$POSTGRES_PASSWORD';
                GRANT ALL PRIVILEGES ON DATABASE tfvisualizer TO root;
              END IF;
            END \$\$;
          EOSQL
        EOT
      ]
    }
  }
}
