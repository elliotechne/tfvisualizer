#!/bin/bash

echo "Waiting for cert-manager to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n cert-manager

echo ""
echo "Applying ZeroSSL ClusterIssuer..."
kubectl apply -f zerossl-clusterissuer.yaml

echo ""
echo "ClusterIssuer applied successfully!"
echo ""
echo "Check status with:"
echo "  kubectl get clusterissuer zerossl-prod"
echo "  kubectl describe clusterissuer zerossl-prod"
