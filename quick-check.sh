#!/bin/bash

NAMESPACE="tfvisualizer"

echo "Quick Status Check"
echo "=================="
echo ""

echo "App Pods:"
kubectl get pods -n $NAMESPACE -l app=tfvisualizer
echo ""

APP_POD=$(kubectl get pods -n $NAMESPACE -l app=tfvisualizer -o jsonpath='{.items[0].metadata.name}')

if [ -z "$APP_POD" ]; then
  echo "ERROR: No app pods found!"
  exit 1
fi

echo "Pod Status Details:"
kubectl get pod $APP_POD -n $NAMESPACE -o jsonpath='{.status.phase}: Ready={.status.conditions[?(@.type=="Ready")].status}'
echo ""
echo ""

echo "Recent Pod Logs:"
kubectl logs $APP_POD -n $NAMESPACE --tail=20
echo ""

echo "Service Endpoints:"
kubectl get endpoints tfvisualizer-service -n $NAMESPACE
echo ""

echo "Test from inside pod:"
kubectl exec $APP_POD -n $NAMESPACE -- curl -s -m 2 http://localhost:8080/health || echo "FAILED"
