#!/bin/bash

echo "=========================================="
echo "EXTERNAL ACCESS DIAGNOSTICS"
echo "=========================================="
echo ""

echo "1. NGINX INGRESS LOADBALANCER"
echo "=============================="
kubectl get svc -n ingress-nginx ingress-nginx-controller
echo ""

LB_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "LoadBalancer IP: $LB_IP"
echo ""

echo "2. NGINX INGRESS CONTROLLER PODS"
echo "================================="
kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller
echo ""

echo "3. DNS RECORDS"
echo "=============="
echo "Checking DNS for tfvisualizer.net..."
dig tfvisualizer.net +short
echo ""
echo "Checking DNS for www.tfvisualizer.net..."
dig www.tfvisualizer.net +short
echo ""

echo "4. EXTERNAL-DNS STATUS"
echo "======================"
kubectl get pods -n external-dns
echo ""
echo "External-DNS logs (last 20 lines):"
kubectl logs -n external-dns deployment/external-dns --tail=20
echo ""

echo "5. INGRESS RESOURCE DETAILS"
echo "============================"
kubectl get ingress -n tfvisualizer -o wide
echo ""

echo "6. TEST HTTP TO LOADBALANCER IP (bypassing DNS)"
echo "================================================"
if [ -n "$LB_IP" ]; then
  echo "Testing HTTP with Host header..."
  curl -v -H "Host: tfvisualizer.net" http://$LB_IP/health 2>&1 | head -30
fi
echo ""

echo "7. TEST DIRECT TO DOMAIN (if DNS configured)"
echo "============================================="
echo "Testing HTTP to tfvisualizer.net..."
curl -v http://tfvisualizer.net/health 2>&1 | head -30
echo ""

echo "8. NGINX INGRESS CONTROLLER LOGS (errors only)"
echo "==============================================="
NGINX_POD=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].metadata.name}')
if [ -n "$NGINX_POD" ]; then
  kubectl logs $NGINX_POD -n ingress-nginx --tail=50 | grep -i error || echo "No errors found"
fi
echo ""

echo "=========================================="
echo "EXTERNAL ACCESS DIAGNOSTIC COMPLETE"
echo "=========================================="
