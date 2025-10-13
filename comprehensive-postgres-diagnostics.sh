#!/bin/bash

NAMESPACE="tfvisualizer"

echo "=========================================="
echo "COMPREHENSIVE POSTGRESQL DIAGNOSTICS"
echo "=========================================="
echo ""

echo "1. PostgreSQL Pod Status"
echo "------------------------"
kubectl get pods -n $NAMESPACE -l app=postgres
echo ""

echo "2. PostgreSQL Service and Endpoints"
echo "-----------------------------------"
kubectl get svc postgres -n $NAMESPACE
echo ""
kubectl get endpoints postgres -n $NAMESPACE
echo ""

echo "3. Check if PostgreSQL is actually accepting connections"
echo "--------------------------------------------------------"
kubectl exec postgres-0 -n $NAMESPACE -- pg_isready -h localhost -U tfuser
echo ""

echo "4. Check PostgreSQL logs for lifecycle hook execution"
echo "-----------------------------------------------------"
echo "Last 50 lines of PostgreSQL logs:"
kubectl logs postgres-0 -n $NAMESPACE --tail=50
echo ""

echo "5. Verify root database and role exist"
echo "--------------------------------------"
kubectl exec postgres-0 -n $NAMESPACE -- psql -U tfuser -d tfvisualizer -c "\l" | grep root || echo "No root database found"
kubectl exec postgres-0 -n $NAMESPACE -- psql -U tfuser -d tfvisualizer -c "\du" | grep root || echo "No root role found"
echo ""

echo "6. Get app pod name and test connectivity FROM app pod"
echo "-------------------------------------------------------"
APP_POD=$(kubectl get pods -n $NAMESPACE -l app=tfvisualizer -o jsonpath='{.items[0].metadata.name}')
echo "App pod: $APP_POD"
echo ""

if [ -n "$APP_POD" ]; then
  echo "6a. Test DNS resolution from app pod:"
  kubectl exec $APP_POD -n $NAMESPACE -- nslookup postgres.tfvisualizer.svc.cluster.local || echo "DNS resolution failed"
  echo ""

  echo "6b. Test pg_isready from app pod:"
  kubectl exec $APP_POD -n $NAMESPACE -- pg_isready -h postgres.tfvisualizer.svc.cluster.local -p 5432 -U tfuser || echo "pg_isready failed"
  echo ""

  echo "6c. Get PostgreSQL service IP and test direct connection:"
  PG_SERVICE_IP=$(kubectl get svc postgres -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')
  echo "PostgreSQL service IP: $PG_SERVICE_IP"

  if [ "$PG_SERVICE_IP" != "None" ]; then
    kubectl exec $APP_POD -n $NAMESPACE -- nc -zv $PG_SERVICE_IP 5432 2>&1 || echo "Direct IP connection failed"
  else
    echo "Headless service detected, getting pod IP..."
    PG_POD_IP=$(kubectl get pod postgres-0 -n $NAMESPACE -o jsonpath='{.status.podIP}')
    echo "PostgreSQL pod IP: $PG_POD_IP"
    kubectl exec $APP_POD -n $NAMESPACE -- nc -zv $PG_POD_IP 5432 2>&1 || echo "Direct pod IP connection failed"
  fi
  echo ""

  echo "6d. Check app pod environment variables:"
  kubectl exec $APP_POD -n $NAMESPACE -- env | grep -E "(DATABASE_URL|DB_HOST|DB_PORT|DB_NAME|DB_USER)" || echo "Env vars not found"
  echo ""

  echo "6e. Check app pod logs (last 30 lines):"
  kubectl logs $APP_POD -n $NAMESPACE --tail=30
  echo ""
else
  echo "No app pod found!"
fi

echo "7. Network Policy Check"
echo "-----------------------"
kubectl get networkpolicy -n $NAMESPACE
echo ""

echo "8. PostgreSQL StatefulSet Status"
echo "--------------------------------"
kubectl get statefulset postgres -n $NAMESPACE
echo ""

echo "=========================================="
echo "DIAGNOSTICS COMPLETE"
echo "=========================================="
