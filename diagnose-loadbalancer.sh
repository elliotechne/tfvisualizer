#!/bin/bash

NAMESPACE="tfvisualizer"

echo "=========================================="
echo "LOADBALANCER DIAGNOSTICS"
echo "=========================================="
echo ""

echo "1. LoadBalancer Service Status"
echo "-------------------------------"
kubectl get svc tfvisualizer-service -n $NAMESPACE -o wide
echo ""

echo "2. LoadBalancer External IP"
echo "---------------------------"
LB_IP=$(kubectl get svc tfvisualizer-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "External IP: $LB_IP"
echo ""

echo "3. Service Endpoints"
echo "-------------------"
kubectl get endpoints tfvisualizer-service -n $NAMESPACE
echo ""

echo "4. App Pod Status"
echo "-----------------"
kubectl get pods -n $NAMESPACE -l app=tfvisualizer -o wide
echo ""

echo "5. Check App Pod Readiness"
echo "-------------------------"
APP_POD=$(kubectl get pods -n $NAMESPACE -l app=tfvisualizer -o jsonpath='{.items[0].metadata.name}')
if [ -n "$APP_POD" ]; then
  echo "App pod: $APP_POD"
  kubectl describe pod $APP_POD -n $NAMESPACE | grep -A 10 "Conditions:"
  echo ""

  echo "6. Test Health Endpoint from Inside Pod"
  echo "---------------------------------------"
  kubectl exec $APP_POD -n $NAMESPACE -- curl -s http://localhost:8080/health || echo "Health check failed"
  echo ""

  echo "7. Recent App Pod Logs"
  echo "---------------------"
  kubectl logs $APP_POD -n $NAMESPACE --tail=30
  echo ""
else
  echo "No app pod found!"
fi

echo "8. LoadBalancer Health Check Configuration"
echo "------------------------------------------"
kubectl get svc tfvisualizer-service -n $NAMESPACE -o jsonpath='{.metadata.annotations}' | jq .
echo ""

echo "9. Network Policy Status"
echo "-----------------------"
kubectl get networkpolicy -n $NAMESPACE
echo ""

if [ -n "$LB_IP" ]; then
  echo "10. Test External Access"
  echo "------------------------"
  echo "Testing HTTP (should redirect to HTTPS)..."
  curl -v -m 5 http://$LB_IP 2>&1 | head -20
  echo ""
fi

echo "=========================================="
echo "DIAGNOSTICS COMPLETE"
echo "=========================================="
