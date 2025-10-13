#!/bin/bash

NAMESPACE="tfvisualizer"

echo "=========================================="
echo "RECREATING REDIS WITH CORRECT PASSWORD"
echo "=========================================="
echo ""

echo "Deleting Redis pod..."
kubectl delete pod redis-0 -n $NAMESPACE

echo ""
echo "Deleting Redis PVC..."
kubectl delete pvc redis-storage-redis-0 -n $NAMESPACE

echo ""
echo "Waiting 5 seconds for cleanup..."
sleep 5

echo ""
echo "Redis pod will be automatically recreated by the StatefulSet."
echo "The new pod will use the correct password from the secret."
echo ""
echo "Monitor the recreation with:"
echo "  kubectl get pods -n $NAMESPACE -l app=redis -w"
