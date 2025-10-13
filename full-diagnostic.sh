#!/bin/bash

NAMESPACE="tfvisualizer"

echo "=========================================="
echo "FULL DIAGNOSTIC - EMPTY REPLY FROM SERVER"
echo "=========================================="
echo ""

echo "1. APP POD STATUS"
echo "================="
kubectl get pods -n $NAMESPACE -l app=tfvisualizer -o wide
echo ""

APP_POD=$(kubectl get pods -n $NAMESPACE -l app=tfvisualizer -o jsonpath='{.items[0].metadata.name}')

if [ -z "$APP_POD" ]; then
  echo "ERROR: No app pods found!"
  echo "Check deployment:"
  kubectl get deployment -n $NAMESPACE
  exit 1
fi

echo "2. POD READINESS CHECK"
echo "======================"
kubectl get pod $APP_POD -n $NAMESPACE -o jsonpath='Phase: {.status.phase}, Ready: {.status.conditions[?(@.type=="Ready")].status}, Reason: {.status.conditions[?(@.type=="Ready")].message}'
echo ""
echo ""

echo "3. POD EVENTS"
echo "============="
kubectl get events -n $NAMESPACE --field-selector involvedObject.name=$APP_POD --sort-by='.lastTimestamp' | tail -10
echo ""

echo "4. APP CONTAINER LOGS (last 50 lines)"
echo "======================================"
kubectl logs $APP_POD -n $NAMESPACE --tail=50
echo ""

echo "5. CHECK IF APP IS LISTENING ON PORT 8080"
echo "=========================================="
kubectl exec $APP_POD -n $NAMESPACE -- netstat -tlnp 2>/dev/null | grep 8080 || echo "Port 8080 NOT listening"
echo ""

echo "6. TEST LOCALHOST:8080 FROM INSIDE POD"
echo "======================================="
kubectl exec $APP_POD -n $NAMESPACE -- curl -v -m 5 http://localhost:8080/health 2>&1
echo ""

echo "7. SERVICE ENDPOINTS"
echo "===================="
kubectl get endpoints tfvisualizer-service -n $NAMESPACE
echo ""
kubectl describe endpoints tfvisualizer-service -n $NAMESPACE
echo ""

echo "8. SERVICE CONFIGURATION"
echo "========================"
kubectl get svc tfvisualizer-service -n $NAMESPACE -o yaml | grep -A 20 "spec:"
echo ""

echo "9. NETWORK POLICY"
echo "================="
kubectl get networkpolicy -n $NAMESPACE
echo ""

echo "10. TEST FROM NGINX INGRESS TO SERVICE"
echo "======================================="
NGINX_POD=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].metadata.name}')
if [ -n "$NGINX_POD" ]; then
  echo "Testing from nginx pod: $NGINX_POD"
  kubectl exec $NGINX_POD -n ingress-nginx -- curl -v -m 5 http://tfvisualizer-service.tfvisualizer.svc.cluster.local:80/health 2>&1 | grep -E "(Connected|HTTP|curl:)"
fi
echo ""

echo "11. INGRESS STATUS"
echo "=================="
kubectl describe ingress tfvisualizer-ingress -n $NAMESPACE | tail -30
echo ""

echo "=========================================="
echo "DIAGNOSTIC COMPLETE"
echo "=========================================="
