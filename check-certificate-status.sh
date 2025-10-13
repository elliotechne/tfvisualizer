#!/bin/bash

NAMESPACE="tfvisualizer"

echo "=========================================="
echo "CERTIFICATE AND LOADBALANCER STATUS"
echo "=========================================="
echo ""

echo "1. DigitalOcean Certificate Status"
echo "-----------------------------------"
doctl compute certificate list --format ID,Name,State,NotAfter,Domains 2>/dev/null || echo "Run: doctl auth init (if doctl is not authenticated)"
echo ""

echo "2. LoadBalancer Configuration"
echo "-----------------------------"
kubectl get svc tfvisualizer-service -n $NAMESPACE -o yaml | grep -A 20 "annotations:"
echo ""

echo "3. LoadBalancer Status"
echo "---------------------"
kubectl describe svc tfvisualizer-service -n $NAMESPACE | grep -A 10 "LoadBalancer Ingress"
echo ""

echo "4. Check if certificate ID is set"
echo "---------------------------------"
CERT_ID=$(kubectl get svc tfvisualizer-service -n $NAMESPACE -o jsonpath='{.metadata.annotations.service\.beta\.kubernetes\.io/do-loadbalancer-certificate-id}')
echo "Certificate ID: $CERT_ID"
echo ""

if [ -n "$CERT_ID" ]; then
  echo "5. Certificate Details from DigitalOcean"
  echo "---------------------------------------"
  doctl compute certificate get $CERT_ID 2>/dev/null || echo "Cannot retrieve certificate details"
fi

echo ""
echo "=========================================="
echo "DIAGNOSTICS COMPLETE"
echo "=========================================="
echo ""
echo "Common issues:"
echo "1. Certificate not yet verified by Let's Encrypt (can take 5-10 minutes)"
echo "2. DNS not pointing to LoadBalancer IP"
echo "3. Certificate ID not properly attached to LoadBalancer"
