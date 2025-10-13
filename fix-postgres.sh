#!/bin/bash

# PostgreSQL Pod Fix Script
# This script helps diagnose and fix PostgreSQL initialization issues

set -e

NAMESPACE="tfvisualizer"

echo "============================================"
echo "PostgreSQL Fix Script"
echo "============================================"
echo ""

echo "1. Checking PostgreSQL pod status..."
if ! kubectl get pod postgres-0 -n $NAMESPACE &>/dev/null; then
    echo "❌ PostgreSQL pod does not exist!"
    echo "Run 'cd terraform && terraform apply' to create it."
    exit 1
fi

kubectl get pod postgres-0 -n $NAMESPACE
echo ""

echo "2. Checking PostgreSQL logs for errors..."
echo "-------------------------------------------"
kubectl logs postgres-0 -n $NAMESPACE --tail=50 2>&1 | grep -E "FATAL|ERROR|WARNING|ready to accept" || echo "No obvious errors found"
echo ""

echo "3. Checking PVC status..."
kubectl get pvc postgres-storage-postgres-0 -n $NAMESPACE
echo ""

echo "4. Current probe configuration..."
kubectl get pod postgres-0 -n $NAMESPACE -o jsonpath='{.spec.containers[0].readinessProbe}' | jq
echo ""

read -p "Do you want to delete the PostgreSQL pod to force a restart? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Deleting postgres-0 pod..."
    kubectl delete pod postgres-0 -n $NAMESPACE
    echo ""
    echo "Pod deleted. Kubernetes will recreate it automatically."
    echo ""
    echo "Watch the restart:"
    echo "kubectl get pod postgres-0 -n $NAMESPACE -w"
    echo ""
    echo "Check logs:"
    echo "kubectl logs postgres-0 -n $NAMESPACE -f"
else
    echo "Skipping pod deletion."
fi

echo ""
read -p "Do you want to delete the PVC and start fresh? (WARNING: This will delete all data!) (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "⚠️  WARNING: This will delete all PostgreSQL data!"
    read -p "Are you absolutely sure? Type 'DELETE' to confirm: " CONFIRM

    if [ "$CONFIRM" == "DELETE" ]; then
        echo "Deleting StatefulSet..."
        kubectl delete statefulset postgres -n $NAMESPACE --cascade=false

        echo "Deleting PVC..."
        kubectl delete pvc postgres-storage-postgres-0 -n $NAMESPACE

        echo ""
        echo "Waiting for resources to be deleted..."
        sleep 5

        echo "Reapplying Terraform to recreate..."
        cd terraform
        terraform apply -auto-approve

        echo ""
        echo "PostgreSQL recreated with fresh data."
        echo "Watch the startup:"
        echo "kubectl logs postgres-0 -n $NAMESPACE -f"
    else
        echo "Aborting PVC deletion."
    fi
else
    echo "Skipping PVC deletion."
fi

echo ""
echo "============================================"
echo "Script Complete"
echo "============================================"
