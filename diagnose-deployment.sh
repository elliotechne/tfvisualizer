#!/bin/bash

# Comprehensive deployment diagnostic script
set -e

NAMESPACE="tfvisualizer"

echo "============================================"
echo "Kubernetes Deployment Diagnostic"
echo "============================================"
echo ""

echo "1. CHECKING POSTGRESQL POD"
echo "-------------------------------------------"
if kubectl get pod postgres-0 -n $NAMESPACE &>/dev/null; then
    echo "Status:"
    kubectl get pod postgres-0 -n $NAMESPACE
    echo ""

    echo "Last 20 log lines:"
    kubectl logs postgres-0 -n $NAMESPACE --tail=20 2>&1 | head -20
    echo ""
else
    echo "❌ PostgreSQL pod does not exist!"
    echo ""
fi

echo "2. CHECKING APPLICATION POD"
echo "-------------------------------------------"
APP_POD=$(kubectl get pods -n $NAMESPACE -l app=tfvisualizer -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$APP_POD" ]; then
    echo "Pod name: $APP_POD"
    echo ""

    echo "Status:"
    kubectl get pod $APP_POD -n $NAMESPACE
    echo ""

    echo "Probe configuration:"
    kubectl get pod $APP_POD -n $NAMESPACE -o jsonpath='{.spec.containers[0].readinessProbe}' | jq
    echo ""

    echo "Last 50 log lines:"
    kubectl logs $APP_POD -n $NAMESPACE --tail=50 2>&1
    echo ""

    echo "Checking if app is listening on port 80:"
    kubectl exec $APP_POD -n $NAMESPACE -- netstat -tlnp 2>/dev/null | grep :80 || echo "❌ Nothing listening on port 80"
    echo ""

    echo "Checking processes:"
    kubectl exec $APP_POD -n $NAMESPACE -- ps aux 2>/dev/null | grep -E "python|gunicorn|wait-for-db" || echo "No Python/Gunicorn processes found"
    echo ""
else
    echo "❌ No application pod found!"
    echo ""
fi

echo "3. CHECKING RECENT EVENTS"
echo "-------------------------------------------"
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | tail -15
echo ""

echo "4. CHECKING ALL PODS"
echo "-------------------------------------------"
kubectl get pods -n $NAMESPACE -o wide
echo ""

echo "5. CHECKING SERVICES"
echo "-------------------------------------------"
kubectl get svc -n $NAMESPACE
echo ""

echo "============================================"
echo "Diagnostic Complete"
echo "============================================"
