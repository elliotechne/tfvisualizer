#!/bin/bash

NAMESPACE="tfvisualizer"

echo "============================================"
echo "Checking Kubernetes Services"
echo "============================================"
echo ""

echo "1. All services in namespace:"
echo "-------------------------------------------"
kubectl get svc -n $NAMESPACE
echo ""

echo "2. PostgreSQL service details:"
echo "-------------------------------------------"
kubectl get svc postgres -n $NAMESPACE -o yaml 2>&1 || echo "❌ PostgreSQL service does not exist!"
echo ""

echo "3. PostgreSQL endpoints:"
echo "-------------------------------------------"
kubectl get endpoints postgres -n $NAMESPACE 2>&1 || echo "❌ PostgreSQL endpoints do not exist!"
echo ""

echo "4. All pods in namespace:"
echo "-------------------------------------------"
kubectl get pods -n $NAMESPACE -o wide
echo ""

echo "5. PostgreSQL StatefulSet:"
echo "-------------------------------------------"
kubectl get statefulset postgres -n $NAMESPACE 2>&1 || echo "❌ PostgreSQL StatefulSet does not exist!"
echo ""

echo "6. Test DNS from app pod:"
echo "-------------------------------------------"
APP_POD=$(kubectl get pods -n $NAMESPACE -l app=tfvisualizer -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$APP_POD" ]; then
    echo "Testing 'postgres' resolution..."
    kubectl exec $APP_POD -n $NAMESPACE -- nslookup postgres 2>&1
    echo ""

    echo "Testing 'postgres.tfvisualizer' resolution..."
    kubectl exec $APP_POD -n $NAMESPACE -- nslookup postgres.tfvisualizer 2>&1
    echo ""

    echo "Checking /etc/resolv.conf in app pod:"
    kubectl exec $APP_POD -n $NAMESPACE -- cat /etc/resolv.conf
else
    echo "❌ No app pod found"
fi
echo ""

echo "7. Check if Terraform created the service:"
echo "-------------------------------------------"
echo "Running terraform state list | grep postgres..."
cd terraform 2>/dev/null && terraform state list | grep postgres || echo "Not in terraform directory or no state"
echo ""

echo "============================================"
echo "Check Complete"
echo "============================================"
