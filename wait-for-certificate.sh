#!/bin/bash

NAMESPACE="tfvisualizer"

echo "Checking certificate status..."
echo ""

while true; do
  STATUS=$(kubectl get certificate tfvisualizer-tls -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)

  if [ "$STATUS" = "True" ]; then
    echo "✓ Certificate issued successfully!"
    kubectl get certificate tfvisualizer-tls -n $NAMESPACE
    echo ""
    echo "You can now enable HTTPS redirect in ingress.tf:"
    echo '  "nginx.ingress.kubernetes.io/ssl-redirect" = "true"'
    echo '  "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"'
    break
  elif [ "$STATUS" = "False" ]; then
    echo "Certificate issuance failed. Checking details..."
    kubectl describe certificate tfvisualizer-tls -n $NAMESPACE | tail -30
    break
  else
    echo "Certificate status: Pending..."
    echo "Checking challenge status..."
    kubectl get challenges -n $NAMESPACE 2>/dev/null
    echo ""
    echo "Waiting 30 seconds before next check..."
    sleep 30
  fi
done
