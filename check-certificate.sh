#!/bin/bash

NAMESPACE="tfvisualizer"

echo "=========================================="
echo "CERTIFICATE DIAGNOSTICS"
echo "=========================================="
echo ""

echo "1. ClusterIssuer Status"
echo "----------------------"
kubectl get clusterissuer
echo ""
kubectl describe clusterissuer zerossl-prod
echo ""

echo "2. Certificate Status"
echo "--------------------"
kubectl get certificate -n $NAMESPACE
echo ""

echo "3. Certificate Details"
echo "---------------------"
kubectl describe certificate tfvisualizer-tls -n $NAMESPACE
echo ""

echo "4. Certificate Request"
echo "---------------------"
kubectl get certificaterequest -n $NAMESPACE
echo ""
kubectl describe certificaterequest -n $NAMESPACE | tail -50
echo ""

echo "5. ACME Challenge Status"
echo "-----------------------"
kubectl get challenges -n $NAMESPACE
echo ""
kubectl describe challenges -n $NAMESPACE 2>/dev/null | tail -50
echo ""

echo "6. cert-manager logs (last 50 lines)"
echo "------------------------------------"
kubectl logs -n cert-manager deployment/cert-manager --tail=50
echo ""

echo "7. Check if ZeroSSL EAB secret exists"
echo "-------------------------------------"
kubectl get secret zerossl-eab-secret -n cert-manager
echo ""

echo "8. Ingress Annotations"
echo "---------------------"
kubectl get ingress tfvisualizer-ingress -n $NAMESPACE -o jsonpath='{.metadata.annotations}' | jq .
echo ""

echo "=========================================="
echo "DIAGNOSTICS COMPLETE"
echo "=========================================="
echo ""
echo "Common issues:"
echo "1. ClusterIssuer not ready - check ZeroSSL EAB credentials"
echo "2. DNS not pointing to LoadBalancer - HTTP-01 challenge needs valid DNS"
echo "3. Ingress class mismatch - must be 'nginx'"
echo "4. Challenge pod can't be reached - check network policies"
