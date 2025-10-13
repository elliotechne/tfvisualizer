#!/bin/bash

NAMESPACE="tfvisualizer"

echo "============================================"
echo "Connection String Verification"
echo "============================================"
echo ""

echo "1. PostgreSQL Pod Status and IP:"
echo "-------------------------------------------"
kubectl get pod postgres-0 -n $NAMESPACE -o wide
PG_IP=$(kubectl get pod postgres-0 -n $NAMESPACE -o jsonpath='{.status.podIP}' 2>/dev/null)
echo "PostgreSQL Pod IP: $PG_IP"
echo ""

echo "2. PostgreSQL Service:"
echo "-------------------------------------------"
kubectl get svc postgres -n $NAMESPACE
echo ""

echo "3. PostgreSQL Service Endpoints:"
echo "-------------------------------------------"
kubectl get endpoints postgres -n $NAMESPACE
echo ""

echo "4. App Pod Environment Variables:"
echo "-------------------------------------------"
APP_POD=$(kubectl get pods -n $NAMESPACE -l app=tfvisualizer -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$APP_POD" ]; then
    echo "App Pod: $APP_POD"
    echo ""
    echo "DATABASE_URL:"
    kubectl exec $APP_POD -n $NAMESPACE -- env | grep DATABASE_URL || echo "Not set"
    echo ""
    echo "DB_HOST:"
    kubectl exec $APP_POD -n $NAMESPACE -- env | grep DB_HOST || echo "Not set"
    echo ""
    echo "DB_PORT:"
    kubectl exec $APP_POD -n $NAMESPACE -- env | grep DB_PORT || echo "Not set"
    echo ""
    echo "DB_NAME:"
    kubectl exec $APP_POD -n $NAMESPACE -- env | grep DB_NAME || echo "Not set"
    echo ""
    echo "DB_USER:"
    kubectl exec $APP_POD -n $NAMESPACE -- env | grep DB_USER || echo "Not set"
    echo ""
else
    echo "❌ No app pod found"
fi

echo "5. Test Direct IP Connection from App Pod:"
echo "-------------------------------------------"
if [ -n "$APP_POD" ] && [ -n "$PG_IP" ]; then
    echo "Testing TCP connection to PostgreSQL pod IP ($PG_IP:5432)..."
    kubectl exec $APP_POD -n $NAMESPACE -- timeout 5 nc -zv $PG_IP 5432 2>&1 || echo "❌ Cannot connect"
    echo ""

    echo "6. Test pg_isready to Pod IP:"
    echo "-------------------------------------------"
    kubectl exec $APP_POD -n $NAMESPACE -- pg_isready -h $PG_IP -p 5432 -U tfuser 2>&1 || echo "❌ pg_isready failed"
    echo ""
fi

echo "7. PostgreSQL Pod Logs (last 20 lines):"
echo "-------------------------------------------"
kubectl logs postgres-0 -n $NAMESPACE --tail=20 2>&1
echo ""

echo "8. Check if PostgreSQL is Ready:"
echo "-------------------------------------------"
kubectl get pod postgres-0 -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
echo ""
echo ""

echo "9. Recommended Connection String (using Pod IP):"
echo "-------------------------------------------"
if [ -n "$PG_IP" ]; then
    echo "DATABASE_URL=postgresql://tfuser:PASSWORD@$PG_IP:5432/tfvisualizer"
    echo "DB_HOST=$PG_IP"
    echo ""
    echo "Update terraform/kubernetes.tf lines 53-54 with:"
    echo "    DATABASE_URL = \"postgresql://tfuser:\${var.postgres_password}@$PG_IP:5432/tfvisualizer\""
    echo "    DB_HOST      = \"$PG_IP\""
fi

echo ""
echo "============================================"
echo "Verification Complete"
echo "============================================"
