#!/bin/bash

# PostgreSQL Diagnostic Script
# This script helps diagnose why PostgreSQL is not starting

set -e

NAMESPACE="tfvisualizer"

echo "========================================="
echo "PostgreSQL Diagnostic Report"
echo "========================================="
echo ""

echo "1. Checking if PostgreSQL StatefulSet exists..."
kubectl get statefulset postgres -n $NAMESPACE 2>/dev/null || echo "   ❌ StatefulSet does not exist - run terraform apply"
echo ""

echo "2. Checking PostgreSQL pod status..."
kubectl get pods -n $NAMESPACE | grep postgres || echo "   ⚠️ No postgres pods found"
echo ""

echo "3. Checking Persistent Volume Claim..."
kubectl get pvc -n $NAMESPACE | grep postgres || echo "   ⚠️ No PVC found"
echo ""

echo "4. Checking database credentials secret..."
kubectl get secret database-credentials -n $NAMESPACE 2>/dev/null && echo "   ✅ Secret exists" || echo "   ❌ Secret missing"
echo ""

echo "5. PostgreSQL pod details (if exists)..."
if kubectl get pod postgres-0 -n $NAMESPACE &>/dev/null; then
    echo "   Status:"
    kubectl get pod postgres-0 -n $NAMESPACE
    echo ""

    echo "   Recent events:"
    kubectl get events -n $NAMESPACE --field-selector involvedObject.name=postgres-0 --sort-by='.lastTimestamp' | tail -10
    echo ""

    echo "   Container state:"
    kubectl get pod postgres-0 -n $NAMESPACE -o jsonpath='{.status.containerStatuses[0].state}' | jq
    echo ""

    echo "   Last 30 log lines:"
    kubectl logs postgres-0 -n $NAMESPACE --tail=30 2>&1 || echo "   ⚠️ Cannot get logs - pod may not be ready"
else
    echo "   ⚠️ postgres-0 pod does not exist yet"
fi
echo ""

echo "6. Checking PVC status..."
if kubectl get pvc postgres-storage-postgres-0 -n $NAMESPACE &>/dev/null; then
    kubectl describe pvc postgres-storage-postgres-0 -n $NAMESPACE | grep -A5 "Status\|Events"
else
    echo "   ⚠️ PVC postgres-storage-postgres-0 does not exist"
fi
echo ""

echo "7. Checking PostgreSQL Service..."
kubectl get service postgres -n $NAMESPACE 2>/dev/null && echo "   ✅ Service exists" || echo "   ❌ Service missing"
echo ""

echo "8. Checking storage class..."
kubectl get storageclass do-block-storage 2>/dev/null && echo "   ✅ Storage class exists" || echo "   ❌ Storage class missing"
echo ""

echo "========================================="
echo "Diagnostic Report Complete"
echo "========================================="
echo ""
echo "Next steps based on findings:"
echo ""
echo "- If StatefulSet missing: Run 'cd terraform && terraform apply'"
echo "- If PVC Pending: Check DigitalOcean volumes, may take 1-2 minutes"
echo "- If Pod CrashLoopBackOff: Check logs above for errors"
echo "- If Pod Pending: Check events above for scheduling issues"
echo "- If Secret missing: Check terraform apply completed successfully"
echo ""
