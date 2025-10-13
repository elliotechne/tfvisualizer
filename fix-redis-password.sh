#!/bin/bash

NAMESPACE="tfvisualizer"

echo "Fixing Redis password..."

# Get the current password from the secret (this is now the correct password after terraform apply)
CORRECT_PASSWORD=$(kubectl get secret database-credentials -n $NAMESPACE -o jsonpath='{.data.redis-password}' | base64 -d)

echo "Current Redis pod status:"
kubectl get pod -n $NAMESPACE -l app=redis

echo ""
echo "Deleting Redis pod to force recreation with new password..."
kubectl delete pod redis-0 -n $NAMESPACE

echo ""
echo "Waiting for Redis to restart (this may take 30-60 seconds)..."
kubectl wait --for=condition=ready pod/redis-0 -n $NAMESPACE --timeout=120s

echo ""
echo "Verifying Redis connection with new password..."
kubectl exec redis-0 -n $NAMESPACE -- redis-cli -a "$CORRECT_PASSWORD" ping

echo ""
echo "Done! Redis should now accept connections with the correct password."
