#!/bin/bash

echo "=========================================="
echo "RESET ZEROSSL CONFIGURATION"
echo "=========================================="
echo ""

echo "Step 1: Delete existing ClusterIssuer and secrets"
echo "-------------------------------------------------"
kubectl delete clusterissuer zerossl-prod 2>/dev/null || echo "ClusterIssuer not found"
kubectl delete secret zerossl-eab-secret -n cert-manager 2>/dev/null || echo "EAB secret not found"
kubectl delete secret zerossl-prod-account-key -n cert-manager 2>/dev/null || echo "Account key not found"
kubectl delete certificate tfvisualizer-tls -n tfvisualizer 2>/dev/null || echo "Certificate not found"
kubectl delete certificaterequest -n tfvisualizer --all 2>/dev/null || echo "No certificate requests"
kubectl delete order -n tfvisualizer --all 2>/dev/null || echo "No orders"
kubectl delete challenge -n tfvisualizer --all 2>/dev/null || echo "No challenges"

echo ""
echo "Step 2: Generate NEW EAB credentials"
echo "------------------------------------"
echo "1. Go to: https://app.zerossl.com/developer"
echo "2. Click 'Generate' under EAB Credentials for ACME Clients"
echo "3. Copy the EAB KID and EAB HMAC Key"
echo ""
echo "Step 3: Update your credentials"
echo "-------------------------------"
echo "Update terraform.tfvars with:"
echo '  letsencrypt_email    = "your-email@example.com"'
echo '  zerossl_eab_kid      = "new-eab-kid"'
echo '  zerossl_eab_hmac_key = "new-eab-hmac-key"'
echo ""
echo "OR set environment variables:"
echo '  export TF_VAR_letsencrypt_email="your-email@example.com"'
echo '  export TF_VAR_zerossl_eab_kid="new-eab-kid"'
echo '  export TF_VAR_zerossl_eab_hmac_key="new-eab-hmac-key"'
echo ""
echo "Step 4: Apply terraform"
echo "----------------------"
echo "  terraform apply"
echo ""
echo "=========================================="
echo "CLEANUP COMPLETE"
echo "=========================================="
