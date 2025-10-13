#!/bin/bash

echo "This will enable HTTPS redirect in your ingress configuration."
echo ""
echo "Make sure the certificate is issued first by running:"
echo "  kubectl get certificate tfvisualizer-tls -n tfvisualizer"
echo ""
read -p "Is the certificate ready? (yes/no): " answer

if [ "$answer" != "yes" ]; then
  echo "Please wait for the certificate to be issued first."
  exit 1
fi

echo ""
echo "To enable HTTPS redirect:"
echo "1. Edit terraform/ingress.tf"
echo "2. Change these annotations:"
echo '   "nginx.ingress.kubernetes.io/ssl-redirect" = "true"'
echo '   "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"'
echo "3. Run: terraform apply"
echo ""
echo "Or run these commands:"
echo ""
cat <<'EOF'
cd terraform
sed -i 's/"nginx.ingress.kubernetes.io\/ssl-redirect".*= "false"/"nginx.ingress.kubernetes.io\/ssl-redirect"          = "true"/g' ingress.tf
sed -i 's/"nginx.ingress.kubernetes.io\/force-ssl-redirect".*= "false"/"nginx.ingress.kubernetes.io\/force-ssl-redirect"    = "true"/g' ingress.tf
terraform apply
EOF
