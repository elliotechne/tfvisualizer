#!/bin/bash

# Create root role in PostgreSQL manually

NAMESPACE="tfvisualizer"

echo "Creating root role in PostgreSQL..."

# Get the postgres password from the secret
PG_PASSWORD=$(kubectl get secret database-credentials -n $NAMESPACE -o jsonpath='{.data.postgres-password}' | base64 -d)

# Create the role
kubectl exec -it postgres-0 -n $NAMESPACE -- bash -c "PGPASSWORD='$PG_PASSWORD' psql -U tfuser -d tfvisualizer" <<EOF
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'root') THEN
    CREATE ROLE root WITH SUPERUSER LOGIN PASSWORD '$PG_PASSWORD';
    GRANT ALL PRIVILEGES ON DATABASE tfvisualizer TO root;
    RAISE NOTICE 'Role root created successfully';
  ELSE
    RAISE NOTICE 'Role root already exists';
  END IF;
END
\$\$;
EOF

echo ""
echo "Done! Verifying roles..."

kubectl exec postgres-0 -n $NAMESPACE -- psql -U tfuser -d tfvisualizer -c "\du"
