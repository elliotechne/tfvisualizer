#!/bin/bash

NAMESPACE="tfvisualizer"

echo "=========================================="
echo "INGRESS DIAGNOSTICS"
echo "=========================================="
echo ""

echo "1. Application Pods Status"
echo "--------------------------"
kubectl get pods -n $NAMESPACE -l app=tfvisualizer
echo ""

echo "2. Application Service"
echo "---------------------"
kubectl get svc tfvisualizer-service -n $NAMESPACE
echo ""

echo "3. Service Endpoints"
echo "-------------------"
kubectl get endpoints tfvisualizer-service -n $NAMESPACE
echo ""

echo "4. Nginx Ingress Controller"
echo "---------------------------"
kubectl get pods -n ingress-nginx
echo ""

echo "5. Nginx Ingress Service (LoadBalancer)"
echo "---------------------------------------"
kubectl get svc -n ingress-nginx
echo ""

echo "6. Ingress Resource"
echo "------------------"
kubectl get ingress -n $NAMESPACE
echo ""

echo "7. Ingress Details"
echo "-----------------"
kubectl describe ingress tfvisualizer-ingress -n $NAMESPACE
echo ""

echo "8. Certificate Status"
echo "--------------------"
kubectl get certificate -n $NAMESPACE
echo ""

echo "9. Test App Health from Inside Cluster"
echo "--------------------------------------"
APP_POD=$(kubectl get pods -n $NAMESPACE -l app=tfvisualizer -o jsonpath='{.items[0].metadata.name}')
if [ -n "$APP_POD" ]; then
  echo "Testing from pod: $APP_POD"
  kubectl exec $APP_POD -n $NAMESPACE -- curl -s http://localhost:8080/health || echo "Health check failed"
  echo ""
fi

echo "10. Nginx Ingress Controller Logs (last 30 lines)"
echo "-------------------------------------------------"
NGINX_POD=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].metadata.name}')
if [ -n "$NGINX_POD" ]; then
  kubectl logs $NGINX_POD -n ingress-nginx --tail=30
fi
echo ""

echo "11. Test Connection to Service from Nginx Namespace"
echo "---------------------------------------------------"
if [ -n "$NGINX_POD" ]; then
  kubectl exec $NGINX_POD -n ingress-nginx -- curl -s -m 5 http://tfvisualizer-service.tfvisualizer.svc.cluster.local:80/health || echo "Connection to service failed"
fi
echo ""

echo "=========================================="
echo "DIAGNOSTICS COMPLETE"
echo "=========================================="
