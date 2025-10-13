#!/bin/bash

echo "Getting LoadBalancer IP..."
LB_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "LoadBalancer IP: $LB_IP"
echo ""

if [ -z "$LB_IP" ]; then
  echo "ERROR: LoadBalancer IP not found!"
  exit 1
fi

echo "Testing HTTP connection (bypassing SSL)..."
curl -v -H "Host: tfvisualizer.net" http://$LB_IP/health
echo ""

echo ""
echo "Testing with actual domain (if DNS is configured)..."
curl -v -k http://tfvisualizer.net/health
