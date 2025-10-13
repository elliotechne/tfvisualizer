#!/bin/bash

NAMESPACE="tfvisualizer"

echo "=========================================="
echo "RECREATING POSTGRESQL WITH CORRECT PASSWORD"
echo "=========================================="
echo ""

echo "WARNING: This will delete all data in PostgreSQL!"
echo "Press Ctrl+C within 5 seconds to cancel..."
sleep 5

echo ""
echo "1. Deleting PostgreSQL StatefulSet..."
kubectl delete statefulset postgres -n $NAMESPACE --cascade=orphan

echo ""
echo "2. Deleting PostgreSQL Pod..."
kubectl delete pod postgres-0 -n $NAMESPACE

echo ""
echo "3. Deleting PostgreSQL PersistentVolumeClaim (this removes all data)..."
kubectl delete pvc postgres-storage-postgres-0 -n $NAMESPACE

echo ""
echo "4. Waiting 10 seconds for cleanup..."
sleep 10

echo ""
echo "5. Recreating PostgreSQL StatefulSet with correct password..."
echo "   Run: terraform apply"
echo ""
echo "After terraform apply completes, the PostgreSQL will initialize with the correct password."
