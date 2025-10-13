# SSL Certificate Setup Guide

## Let's Encrypt Configuration

This deployment uses Let's Encrypt for automatic SSL certificate management.

### Requirements

Only one variable is required in your `terraform.tfvars`:

```hcl
letsencrypt_email = "your-email@example.com"
```

Or as environment variable:
```bash
export TF_VAR_letsencrypt_email="your-email@example.com"
```

### Deployment Steps

1. **Apply Terraform:**
   ```bash
   terraform apply
   ```

2. **Wait for certificate issuance (5-10 minutes):**
   - DNS must point to your LoadBalancer IP
   - Let's Encrypt validates via HTTP-01 challenge
   - Certificate is automatically created and renewed

3. **Monitor certificate status:**
   ```bash
   kubectl get certificate -n tfvisualizer
   kubectl describe certificate tfvisualizer-tls -n tfvisualizer
   ```

4. **Check ClusterIssuer:**
   ```bash
   kubectl get clusterissuer
   kubectl describe clusterissuer letsencrypt-prod
   ```

### Architecture

- **cert-manager**: Manages SSL certificates
- **Let's Encrypt**: Free, automated certificate authority
- **HTTP-01 Challenge**: Validates domain ownership via HTTP
- **nginx-ingress**: Handles TLS termination

### Certificate Lifecycle

- **Issuance**: ~5-10 minutes after DNS propagates
- **Renewal**: Automatic at 30 days before expiry
- **Validity**: 90 days per certificate

### Troubleshooting

#### Certificate not issuing

```bash
# Check certificate status
kubectl describe certificate tfvisualizer-tls -n tfvisualizer

# Check certificate request
kubectl get certificaterequest -n tfvisualizer
kubectl describe certificaterequest -n tfvisualizer

# Check ACME challenge
kubectl get challenges -n tfvisualizer
kubectl describe challenges -n tfvisualizer
```

#### DNS not resolving

```bash
# Verify DNS points to LoadBalancer
dig yourdomain.com +short

# Get LoadBalancer IP
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

#### cert-manager issues

```bash
# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager --tail=100

# Check webhook
kubectl logs -n cert-manager deployment/cert-manager-webhook --tail=50
```

### Common Issues

1. **DNS not pointing to LoadBalancer** - HTTP-01 challenge needs valid DNS
2. **Port 80 blocked** - HTTP-01 challenge uses port 80
3. **Rate limits** - Let's Encrypt has rate limits (50 certs/week per domain)
4. **Ingress class mismatch** - Must be 'nginx'

### Enable HTTPS Redirect

Once certificate is issued, enable HTTPS redirect in `ingress.tf`:

```hcl
"nginx.ingress.kubernetes.io/ssl-redirect"       = "true"
"nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"
```

Then apply:
```bash
terraform apply
```
