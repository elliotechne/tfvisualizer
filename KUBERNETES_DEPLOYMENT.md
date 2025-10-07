# TFVisualizer Kubernetes Deployment Guide

Complete guide for deploying TFVisualizer on DigitalOcean Kubernetes Service (DOKS).

---

## 🏗️ Architecture Overview

### Infrastructure Components

**Kubernetes Cluster:**
- **DOKS Cluster**: Managed Kubernetes with auto-scaling (2-5 nodes)
- **Node Size**: s-2vcpu-4gb droplets
- **VPC**: Private networking for secure communication

**Application Layer:**
- **Deployment**: TFVisualizer Flask application
- **Replicas**: 2-10 pods with Horizontal Pod Autoscaler (HPA)
- **Resources**: 250m-1000m CPU, 512Mi-2Gi memory per pod
- **Load Balancer**: Automatic SSL termination with Let's Encrypt

**Data Layer:**
- **PostgreSQL 15**: StatefulSet running on DOKS cluster
- **Redis 7**: StatefulSet running on DOKS cluster
- **Spaces**: S3-compatible object storage (DigitalOcean Spaces)

---

## 🚀 Deployment Methods

### Method 1: Terraform (Recommended)

Terraform automatically provisions the entire infrastructure including Kubernetes resources.

```bash
cd terraform

# Initialize
terraform init \
  -backend-config="access_key=$DO_SPACES_ACCESS_KEY" \
  -backend-config="secret_key=$DO_SPACES_SECRET_KEY"

# Configure variables
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars

# Deploy
terraform plan
terraform apply
```

**What Terraform Creates:**
- ✅ DOKS Kubernetes cluster
- ✅ PostgreSQL StatefulSet on DOKS
- ✅ Redis StatefulSet on DOKS
- ✅ Persistent volumes for databases
- ✅ Spaces bucket for file storage
- ✅ SSL certificate (Let's Encrypt)
- ✅ DNS records
- ✅ Kubernetes namespace
- ✅ Deployment, Service, HPA, PDB
- ✅ Secrets and ConfigMaps

### Method 2: kubectl Manifests

Deploy using raw Kubernetes manifests (useful for existing clusters).

```bash
cd k8s

# Create namespace
kubectl apply -f namespace.yaml

# Deploy PostgreSQL
kubectl apply -f postgres.yaml

# Deploy Redis
kubectl apply -f redis.yaml

# Configure secrets
cp secrets.yaml.example secrets.yaml
nano secrets.yaml
kubectl apply -f secrets.yaml

# Deploy application
kubectl apply -f deployment.yaml

# Verify
kubectl get all -n tfvisualizer
kubectl get pvc -n tfvisualizer  # Check persistent volumes
```

---

## 📊 Kubernetes Resources

### Deployment

```yaml
Replicas: 2 (initial)
Strategy: RollingUpdate
  - Max Surge: 1
  - Max Unavailable: 0
Image: tfvisualizer/tfvisualizer:latest
Resources:
  - CPU Request: 250m
  - CPU Limit: 1000m
  - Memory Request: 512Mi
  - Memory Limit: 2Gi
Health Checks:
  - Liveness: /health (30s delay)
  - Readiness: /health (10s delay)
```

### Service (LoadBalancer)

```yaml
Type: LoadBalancer
Ports:
  - HTTP: 80
  - HTTPS: 443
Annotations:
  - SSL redirect enabled
  - Health check: /health
  - Proxy protocol enabled
```

### Horizontal Pod Autoscaler (HPA)

```yaml
Min Replicas: 2
Max Replicas: 10
Metrics:
  - CPU Utilization: 70%
  - Memory Utilization: 80%
```

### Pod Disruption Budget (PDB)

```yaml
Max Unavailable: 1
Ensures high availability during updates
```

---

## 🔐 Secrets Management

### Environment Variables

All secrets are stored in Kubernetes Secret: `tfvisualizer-config`

```bash
# View secrets (base64 encoded)
kubectl get secret tfvisualizer-config -n tfvisualizer -o yaml

# Decode specific secret
kubectl get secret tfvisualizer-config -n tfvisualizer -o jsonpath='{.data.DATABASE_URL}' | base64 -d

# Update secret
kubectl edit secret tfvisualizer-config -n tfvisualizer
kubectl rollout restart deployment/tfvisualizer-app -n tfvisualizer
```

### Recommended: Sealed Secrets

For production, use sealed-secrets to encrypt secrets in Git:

```bash
# Install sealed-secrets
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Install kubeseal CLI
brew install kubeseal

# Seal secrets
kubeseal --format yaml < secrets.yaml > sealed-secrets.yaml

# Commit sealed-secrets.yaml to Git (safe!)
git add sealed-secrets.yaml
```

---

## 📈 Scaling

### Auto-scaling (HPA)

HPA automatically scales based on CPU/memory:

```bash
# View HPA status
kubectl get hpa -n tfvisualizer

# Describe HPA
kubectl describe hpa tfvisualizer-hpa -n tfvisualizer
```

### Manual Scaling

```bash
# Scale to 5 replicas
kubectl scale deployment tfvisualizer-app --replicas=5 -n tfvisualizer

# Scale nodes (DOKS auto-scaler)
# Configured in terraform: kubernetes_min_nodes, kubernetes_max_nodes
```

### Node Pool Scaling

Terraform configures cluster auto-scaling:

```hcl
kubernetes_autoscale  = true
kubernetes_min_nodes  = 2
kubernetes_max_nodes  = 5
```

---

## 🔄 CI/CD Workflow

### GitHub Actions Integration

The workflow automatically:

1. **Validate**: Checks Terraform syntax
2. **Plan**: Shows infrastructure changes
3. **Apply**: Deploys to DOKS (on main branch)
4. **Deploy**: Rolls out new application version

```yaml
# .github/workflows/terraform.yml
- terraform apply
- kubectl rollout restart deployment/tfvisualizer-app
- kubectl rollout status deployment/tfvisualizer-app
```

### Manual Deployment

```bash
# Build and push Docker image to GHCR
docker build -t ghcr.io/elliotechne/tfvisualizer:v1.2.0 .
docker push ghcr.io/elliotechne/tfvisualizer:v1.2.0

# Update Kubernetes
kubectl set image deployment/tfvisualizer-app \
  tfvisualizer=ghcr.io/elliotechne/tfvisualizer:v1.2.0 \
  -n tfvisualizer

# Watch rollout
kubectl rollout status deployment/tfvisualizer-app -n tfvisualizer
```

See [GHCR_SETUP.md](GHCR_SETUP.md) for GitHub Container Registry configuration.

### Rollback

```bash
# View rollout history
kubectl rollout history deployment/tfvisualizer-app -n tfvisualizer

# Rollback to previous version
kubectl rollout undo deployment/tfvisualizer-app -n tfvisualizer

# Rollback to specific revision
kubectl rollout undo deployment/tfvisualizer-app --to-revision=3 -n tfvisualizer
```

---

## 🔍 Monitoring & Debugging

### View Logs

```bash
# All pods
kubectl logs -f -l app=tfvisualizer -n tfvisualizer

# Specific pod
kubectl logs -f tfvisualizer-app-7d8f9c8b5d-abc12 -n tfvisualizer

# Previous container (after crash)
kubectl logs tfvisualizer-app-7d8f9c8b5d-abc12 -n tfvisualizer --previous
```

### Resource Usage

```bash
# Pod metrics
kubectl top pods -n tfvisualizer

# Node metrics
kubectl top nodes

# Detailed resource usage
kubectl describe pod <pod-name> -n tfvisualizer
```

### Health Checks

```bash
# Check pod status
kubectl get pods -n tfvisualizer

# Test health endpoint
kubectl port-forward svc/tfvisualizer-service 8080:80 -n tfvisualizer
curl http://localhost:8080/health
```

### Events

```bash
# View recent events
kubectl get events -n tfvisualizer --sort-by='.lastTimestamp'

# Watch events
kubectl get events -n tfvisualizer --watch
```

### Shell Access

```bash
# Execute shell in pod
kubectl exec -it <pod-name> -n tfvisualizer -- /bin/sh

# Run commands
kubectl exec <pod-name> -n tfvisualizer -- env
kubectl exec <pod-name> -n tfvisualizer -- ps aux
```

---

## 🛠️ Common Operations

### Database Migration

```bash
# Run migration job
kubectl exec -it <pod-name> -n tfvisualizer -- flask db upgrade

# Or create a Job
kubectl create job db-migrate \
  --from=deployment/tfvisualizer-app \
  -n tfvisualizer \
  -- flask db upgrade
```

### Update Environment Variables

```bash
# Edit config
kubectl edit secret tfvisualizer-config -n tfvisualizer

# Restart to apply
kubectl rollout restart deployment/tfvisualizer-app -n tfvisualizer
```

### Certificate Renewal

Certificates are automatically renewed by DigitalOcean. To force renewal:

```bash
# In Terraform
terraform taint digitalocean_certificate.cert
terraform apply
```

### Backup Database

```bash
# Manual backup
kubectl run -i --rm --tty pg-backup --image=postgres:15 --restart=Never -- \
  pg_dump -h $DB_HOST -U $DB_USER -d tfvisualizer > backup.sql

# Restore
kubectl run -i --rm --tty pg-restore --image=postgres:15 --restart=Never -- \
  psql -h $DB_HOST -U $DB_USER -d tfvisualizer < backup.sql
```

---

## 💰 Cost Estimation

### Monthly Costs (Production)

| Resource | Specs | Cost/mo |
|----------|-------|---------|
| DOKS Nodes (2x) | s-2vcpu-4gb | $48 |
| Block Storage (PostgreSQL) | 20GB SSD | $2 |
| Block Storage (Redis) | 5GB SSD | $0.50 |
| Load Balancer | Automatic | $12 |
| Spaces | 250GB | $5 |
| **Total** | | **~$67.50/mo** |

### Auto-scaling Costs

With auto-scaling (2-5 nodes):
- **Minimum**: $67.50/mo (2 nodes)
- **Maximum**: $139.50/mo (5 nodes)
- **Average**: ~$92/mo (2.5 nodes)

**Cost Savings**: Running databases on DOKS saves ~$75/month compared to managed databases!

---

## 📚 Useful Commands Cheat Sheet

```bash
# Get everything
kubectl get all -n tfvisualizer

# Describe resources
kubectl describe deployment tfvisualizer-app -n tfvisualizer
kubectl describe service tfvisualizer-service -n tfvisualizer
kubectl describe hpa tfvisualizer-hpa -n tfvisualizer

# Edit resources
kubectl edit deployment tfvisualizer-app -n tfvisualizer
kubectl edit svc tfvisualizer-service -n tfvisualizer

# Delete resources
kubectl delete pod <pod-name> -n tfvisualizer
kubectl delete deployment tfvisualizer-app -n tfvisualizer

# Port forwarding
kubectl port-forward svc/tfvisualizer-service 8080:80 -n tfvisualizer

# Copy files
kubectl cp <local-file> <pod>:/path/in/pod -n tfvisualizer
kubectl cp <pod>:/path/in/pod <local-file> -n tfvisualizer

# Watch resources
kubectl get pods -n tfvisualizer --watch
kubectl get events -n tfvisualizer --watch

# Resource quotas
kubectl describe resourcequota -n tfvisualizer
kubectl describe limitrange -n tfvisualizer
```

---

## 🔗 Additional Resources

- [Terraform DOKS Documentation](https://registry.terraform.io/providers/digitalocean/digitalocean/latest/docs/resources/kubernetes_cluster)
- [DigitalOcean Kubernetes](https://docs.digitalocean.com/products/kubernetes/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [DOKS Production Checklist](https://docs.digitalocean.com/products/kubernetes/how-to/production-ready/)

---

**Infrastructure managed with Terraform + Kubernetes on DOKS**
