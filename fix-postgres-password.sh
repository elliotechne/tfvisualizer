#!/bin/bash

NAMESPACE="tfvisualizer"

echo "Fixing PostgreSQL password for tfuser..."

# Get the current password from the secret (this is now the correct password after terraform apply)
CORRECT_PASSWORD=$(kubectl get secret database-credentials -n $NAMESPACE -o jsonpath='{.data.postgres-password}' | base64 -d)

echo "Updating password in PostgreSQL..."

# Connect as postgres superuser and update tfuser password
kubectl exec -it postgres-0 -n $NAMESPACE -- bash -c "
psql -U postgres -d tfvisualizer <<EOF
ALTER ROLE tfuser WITH PASSWORD '$CORRECT_PASSWORD';
ALTER ROLE root WITH PASSWORD '$CORRECT_PASSWORD';
EOF
"

echo ""
echo "Password updated! Verifying roles..."
kubectl exec postgres-0 -n $NAMESPACE -- psql -U postgres -d tfvisualizer -c "\du"

echo ""
echo "Done! The app should now be able to connect."
