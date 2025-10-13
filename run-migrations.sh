#!/bin/bash

NAMESPACE="tfvisualizer"
APP_POD=$(kubectl get pods -n $NAMESPACE -l app=tfvisualizer -o jsonpath='{.items[0].metadata.name}')

echo "Running database migrations..."
echo ""

kubectl exec $APP_POD -n $NAMESPACE -- flask db upgrade

echo ""
echo "Checking database tables..."
kubectl exec postgres-0 -n $NAMESPACE -- psql -U tfuser -d tfvisualizer -c "\dt"

echo ""
echo "Migrations complete!"
