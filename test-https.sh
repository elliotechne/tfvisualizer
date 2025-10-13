#!/bin/bash

NAMESPACE="tfvisualizer"

echo "=========================================="
echo "HTTPS CONFIGURATION TEST"
echo "=========================================="
echo ""

echo "1. Get LoadBalancer IP"
echo "---------------------"
LB_IP=$(kubectl get svc tfvisualizer-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "LoadBalancer IP: $LB_IP"
echo ""

echo "2. Check Certificate Configuration"
echo "----------------------------------"
kubectl get svc tfvisualizer-service -n $NAMESPACE -o jsonpath='{.metadata.annotations.service\.beta\.kubernetes\.io/do-loadbalancer-certificate-id}'
echo ""
echo ""

echo "3. Test HTTP (should redirect to HTTPS)"
echo "---------------------------------------"
if [ -n "$LB_IP" ]; then
  curl -I -L http://$LB_IP 2>&1 | head -20
else
  echo "No LoadBalancer IP found"
fi
echo ""

echo "4. Test HTTPS with domain (if DNS is configured)"
echo "------------------------------------------------"
echo "Enter your domain name (or press Enter to skip):"
read DOMAIN

if [ -n "$DOMAIN" ]; then
  echo ""
  echo "Testing HTTP redirect:"
  curl -I http://$DOMAIN 2>&1 | grep -E "(HTTP|Location)" | head -5

  echo ""
  echo "Testing HTTPS:"
  curl -I https://$DOMAIN 2>&1 | grep -E "(HTTP|SSL|subject)" | head -10

  echo ""
  echo "Testing certificate:"
  echo | openssl s_client -servername $DOMAIN -connect $DOMAIN:443 2>/dev/null | openssl x509 -noout -dates -subject
fi

echo ""
echo "=========================================="
echo "TEST COMPLETE"
echo "=========================================="
