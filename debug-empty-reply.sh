#!/bin/bash

NAMESPACE="tfvisualizer"

echo "=========================================="
echo "DEBUG: EMPTY REPLY FROM SERVER"
echo "=========================================="
echo ""

echo "1. Check if app pods are running and READY"
echo "------------------------------------------"
kubectl get pods -n $NAMESPACE -l app=tfvisualizer -o wide
echo ""

echo "2. Check pod readiness in detail"
echo "--------------------------------"
APP_POD=$(kubectl get pods -n $NAMESPACE -l app=tfvisualizer -o jsonpath='{.items[0].metadata.name}')
if [ -n "$APP_POD" ]; then
  kubectl get pod $APP_POD -n $NAMESPACE -o jsonpath='{.status.conditions}' | jq .
  echo ""
fi

echo "3. Check service endpoints (must have IPs)"
echo "------------------------------------------"
kubectl get endpoints tfvisualizer-service -n $NAMESPACE -o yaml
echo ""

echo "4. Test direct connection to pod"
echo "--------------------------------"
if [ -n "$APP_POD" ]; then
  echo "Testing localhost:8080 from inside pod..."
  kubectl exec $APP_POD -n $NAMESPACE -- curl -v -m 5 http://localhost:8080/health 2>&1 | head -30
  echo ""
fi

echo "5. Check if app is listening on port 8080"
echo "-----------------------------------------"
if [ -n "$APP_POD" ]; then
  kubectl exec $APP_POD -n $NAMESPACE -- netstat -tlnp 2>/dev/null | grep 8080 || echo "Port 8080 not listening"
  echo ""
fi

echo "6. Check app logs for errors"
echo "----------------------------"
if [ -n "$APP_POD" ]; then
  kubectl logs $APP_POD -n $NAMESPACE --tail=50
  echo ""
fi

echo "7. Test service from another pod"
echo "--------------------------------"
kubectl run -it --rm debug-curl --image=curlimages/curl --restart=Never -- curl -v -m 5 http://tfvisualizer-service.tfvisualizer.svc.cluster.local:80/health
echo ""

echo "8. Check network policy allows ingress from nginx"
echo "-------------------------------------------------"
kubectl get networkpolicy -n $NAMESPACE -o yaml
echo ""

echo "=========================================="
echo "DIAGNOSTICS COMPLETE"
echo "=========================================="
