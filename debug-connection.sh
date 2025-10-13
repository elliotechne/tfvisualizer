#!/bin/bash

# Debug PostgreSQL Connection Issues
set -e

NAMESPACE="tfvisualizer"

echo "============================================"
echo "PostgreSQL Connection Debug"
echo "============================================"
echo ""

echo "1. POSTGRESQL POD STATUS"
echo "-------------------------------------------"
kubectl get pod postgres-0 -n $NAMESPACE 2>&1 || echo "❌ PostgreSQL pod doesn't exist!"
echo ""

echo "2. POSTGRESQL POD READY CHECK"
echo "-------------------------------------------"
PG_READY=$(kubectl get pod postgres-0 -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
echo "Ready status: $PG_READY"
if [ "$PG_READY" != "True" ]; then
    echo "❌ PostgreSQL pod is NOT ready"
    echo ""
    echo "Recent events:"
    kubectl get events -n $NAMESPACE --field-selector involvedObject.name=postgres-0 --sort-by='.lastTimestamp' | tail -10
else
    echo "✅ PostgreSQL pod is ready"
fi
echo ""

echo "3. POSTGRESQL LOGS (Last 30 lines)"
echo "-------------------------------------------"
kubectl logs postgres-0 -n $NAMESPACE --tail=30 2>&1 || echo "Cannot get logs"
echo ""

echo "4. CHECK IF POSTGRESQL IS ACCEPTING CONNECTIONS"
echo "-------------------------------------------"
kubectl exec postgres-0 -n $NAMESPACE -- pg_isready -h localhost 2>&1 || echo "❌ PostgreSQL not accepting connections"
echo ""

echo "5. CHECK POSTGRESQL SERVICE"
echo "-------------------------------------------"
kubectl get svc postgres -n $NAMESPACE
echo ""
kubectl get endpoints postgres -n $NAMESPACE
echo ""

echo "6. APPLICATION POD STATUS"
echo "-------------------------------------------"
APP_POD=$(kubectl get pods -n $NAMESPACE -l app=tfvisualizer -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$APP_POD" ]; then
    echo "App pod: $APP_POD"
    kubectl get pod $APP_POD -n $NAMESPACE
    echo ""

    echo "7. APPLICATION ENVIRONMENT VARIABLES"
    echo "-------------------------------------------"
    echo "Checking DATABASE_URL and DB_* variables..."
    kubectl exec $APP_POD -n $NAMESPACE -- env | grep -E "^(DATABASE_URL|DB_HOST|DB_PORT|DB_USER|DB_NAME)=" 2>&1 || echo "Cannot get environment variables"
    echo ""

    echo "8. DNS RESOLUTION FROM APP POD"
    echo "-------------------------------------------"
    echo "Testing: postgres.tfvisualizer.svc.cluster.local"
    kubectl exec $APP_POD -n $NAMESPACE -- nslookup postgres.tfvisualizer.svc.cluster.local 2>&1 || echo "DNS resolution failed"
    echo ""

    echo "Testing: postgres.tfvisualizer"
    kubectl exec $APP_POD -n $NAMESPACE -- nslookup postgres.tfvisualizer 2>&1 || echo "DNS resolution failed"
    echo ""

    echo "Testing: postgres"
    kubectl exec $APP_POD -n $NAMESPACE -- nslookup postgres 2>&1 || echo "DNS resolution failed"
    echo ""

    echo "9. NETWORK CONNECTIVITY TEST"
    echo "-------------------------------------------"
    echo "Testing TCP connection to postgres:5432..."
    kubectl exec $APP_POD -n $NAMESPACE -- nc -zv postgres.tfvisualizer.svc.cluster.local 5432 2>&1 || echo "❌ Cannot connect to PostgreSQL port"
    echo ""

    echo "10. TRY POSTGRESQL CONNECTION FROM APP POD"
    echo "-------------------------------------------"
    echo "Attempting connection with pg_isready..."
    kubectl exec $APP_POD -n $NAMESPACE -- sh -c 'pg_isready -h postgres.tfvisualizer.svc.cluster.local -p 5432 -U tfuser' 2>&1 || echo "❌ pg_isready failed from app pod"
    echo ""

    echo "11. APPLICATION LOGS (Last 50 lines)"
    echo "-------------------------------------------"
    kubectl logs $APP_POD -n $NAMESPACE --tail=50
    echo ""
else
    echo "❌ No application pod found"
fi

echo "12. CHECK DATABASE CREDENTIALS SECRET"
echo "-------------------------------------------"
kubectl get secret database-credentials -n $NAMESPACE 2>&1 || echo "❌ Secret doesn't exist"
echo ""

echo "13. CHECK APP CONFIG SECRET"
echo "-------------------------------------------"
kubectl get secret tfvisualizer-config -n $NAMESPACE 2>&1 || echo "❌ Secret doesn't exist"
echo ""

echo "14. NETWORK POLICIES"
echo "-------------------------------------------"
kubectl get networkpolicy -n $NAMESPACE
echo ""

echo "============================================"
echo "Debug Complete"
echo "============================================"
echo ""
echo "SUMMARY:"
echo "--------"
echo "PostgreSQL Pod Ready: $PG_READY"
echo ""
echo "Next steps:"
echo "- If PostgreSQL pod not Ready: Check PostgreSQL logs above"
echo "- If DNS fails: Check service exists and namespace is correct"
echo "- If TCP connection fails: Check network policies"
echo "- If pg_isready fails: Check credentials"
echo ""
