# Infrastructure as Code Summary

Complete overview of TFVisualizer's Terraform-managed infrastructure.

---

## 🎯 Architecture Overview

All infrastructure is defined as code using **Terraform** and **Kubernetes manifests**.

```
tfvisualizer/
├── terraform/           # PRIMARY: All infrastructure definitions
│   ├── backend.tf      # State backend & providers
│   ├── main.tf         # VPC, Spaces, SSL, DNS, Project
│   ├── kubernetes.tf   # DOKS, App deployment, Services, Secrets
│   ├── databases.tf    # PostgreSQL & Redis StatefulSets
│   ├── variables.tf    # Input variables
│   ├── outputs.tf      # Output values
│   └── terraform.tfvars.example
│
└── k8s/                # REFERENCE: YAML manifests only
    ├── namespace.yaml
    ├── postgres.yaml
    ├── redis.yaml
    ├── deployment.yaml
    ├── secrets.yaml.example
    └── TERRAFORM_NOTE.md  # Explains YAML → Terraform mapping
```

---

## 📊 Infrastructure Components

### Managed by Terraform

| Component | File | Description |
|-----------|------|-------------|
| **DOKS Cluster** | `kubernetes.tf` | Managed Kubernetes cluster (2-5 nodes, auto-scaling) |
| **PostgreSQL** | `databases.tf` | StatefulSet on DOKS (20Gi storage) |
| **Redis** | `databases.tf` | StatefulSet on DOKS (5Gi storage) |
| **Application** | `kubernetes.tf` | Deployment (2-10 replicas, HPA) |
| **Load Balancer** | `kubernetes.tf` | Service with SSL termination |
| **SSL Certificate** | `main.tf` | Let's Encrypt certificate |
| **DNS Records** | `main.tf` | Domain A records |
| **Spaces Bucket** | `main.tf` | S3-compatible storage |
| **Secrets** | `kubernetes.tf`, `databases.tf` | All credentials |
| **ConfigMaps** | `kubernetes.tf` | Non-sensitive config |

### Cost Breakdown

| Resource | Monthly Cost |
|----------|--------------|
| DOKS Nodes (2x s-2vcpu-4gb) | $48.00 |
| PostgreSQL Storage (20Gi) | $2.00 |
| Redis Storage (5Gi) | $0.50 |
| Load Balancer | $12.00 |
| Spaces (250GB) | $5.00 |
| **Total** | **$67.50/mo** |

**Savings vs. Managed Databases:** ~$72.50/month (97% reduction!)

---

## 🚀 Deployment Workflow

### Complete Deployment (Terraform)

```bash
# 1. Setup environment
export DIGITALOCEAN_TOKEN="dop_v1_your_token"
export DO_SPACES_ACCESS_KEY="your_key"
export DO_SPACES_SECRET_KEY="your_secret"

# 2. Initialize Terraform
cd terraform
terraform init \
  -backend-config="access_key=$DO_SPACES_ACCESS_KEY" \
  -backend-config="secret_key=$DO_SPACES_SECRET_KEY"

# 3. Configure variables
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Edit with your values

# 4. Preview changes
terraform plan

# 5. Deploy everything
terraform apply
```

**What gets created:**
1. DigitalOcean VPC
2. DOKS Kubernetes cluster
3. Kubernetes namespace
4. PostgreSQL StatefulSet + PVC
5. Redis StatefulSet + PVC
6. Application Deployment
7. LoadBalancer Service with SSL
8. HorizontalPodAutoscaler
9. PodDisruptionBudget
10. NetworkPolicy
11. All Secrets and ConfigMaps
12. DNS A records
13. Spaces bucket
14. SSL certificate
15. DigitalOcean Project

**Time:** ~10-15 minutes

### Partial Deployment (kubectl + YAML)

```bash
# Only if you have an existing cluster
cd k8s
kubectl apply -f namespace.yaml
kubectl apply -f postgres.yaml
kubectl apply -f redis.yaml
kubectl apply -f secrets.yaml
kubectl apply -f deployment.yaml
```

⚠️ **Limitations:**
- Doesn't create DOKS cluster
- Doesn't create DNS/SSL
- No state management
- No drift detection
- Manual dependency ordering

---

## 🔄 CI/CD Integration

### GitHub Actions Workflow

The `.github/workflows/terraform.yml` workflow:

1. **Build Docker Image**
   - Builds and pushes to ghcr.io
   - Tags with branch, SHA, and latest

2. **Validate Terraform**
   - Checks syntax and formatting
   - Runs `terraform validate`

3. **Plan Changes**
   - Shows infrastructure changes
   - Comments on PRs

4. **Apply Changes** (main branch only)
   - Deploys infrastructure
   - Updates Kubernetes deployment
   - Restarts pods with new image

### Triggering Deployment

```bash
# 1. Make changes
git add .
git commit -m "Update application"

# 2. Push to main
git push origin main

# 3. GitHub Actions automatically:
# - Builds Docker image
# - Pushes to ghcr.io/elliotechne/tfvisualizer:latest
# - Runs terraform apply
# - Updates Kubernetes deployment
```

---

## 📝 Terraform State Management

### Backend Configuration

State is stored in **DigitalOcean Spaces** (S3-compatible):

```hcl
terraform {
  backend "s3" {
    endpoint = "nyc3.digitaloceanspaces.com"
    region   = "us-east-1"
    bucket   = "tfvisualizer-terraform-state"
    key      = "production/terraform.tfstate"
  }
}
```

### State Operations

```bash
# View current state
terraform show

# List resources
terraform state list

# Pull state (backup)
terraform state pull > terraform.tfstate.backup

# Push state (restore)
terraform state push terraform.tfstate.backup
```

---

## 🔍 Resource Dependencies

Terraform automatically handles dependencies:

```
digitalocean_vpc
    ↓
digitalocean_kubernetes_cluster
    ↓
kubernetes_namespace
    ↓
├── kubernetes_stateful_set (postgres)
├── kubernetes_stateful_set (redis)
├── kubernetes_secret (database_credentials)
│   ↓
├── kubernetes_secret (app_config)
│   ↓
└── kubernetes_deployment (app)
    ↓
    kubernetes_service (app)
        ↓
        digitalocean_record (DNS)
```

---

## 🛠️ Common Operations

### Update Application

```bash
# Update image tag
cd terraform
nano terraform.tfvars  # Change docker_tag
terraform apply

# Or update via kubectl
kubectl set image deployment/tfvisualizer-app \
  tfvisualizer=ghcr.io/elliotechne/tfvisualizer:v2.0.0 \
  -n tfvisualizer
```

### Scale Application

```bash
# Update replicas
cd terraform
nano terraform.tfvars  # Change app_replicas
terraform apply

# Or scale manually
kubectl scale deployment tfvisualizer-app --replicas=5 -n tfvisualizer
```

### Update Database Password

```bash
# Update in terraform.tfvars
cd terraform
nano terraform.tfvars  # Change postgres_password

# Apply changes
terraform apply

# Restart databases
kubectl delete pod postgres-0 -n tfvisualizer
kubectl rollout restart deployment tfvisualizer-app -n tfvisualizer
```

### Add Storage

```bash
# Update storage size
cd terraform
nano terraform.tfvars  # Change postgres_storage_size to "50Gi"

# Apply
terraform apply

# Restart pod to expand
kubectl delete pod postgres-0 -n tfvisualizer
```

---

## 📊 Monitoring State

### View Deployed Resources

```bash
# Terraform view
cd terraform
terraform show

# Kubernetes view
kubectl get all -n tfvisualizer
kubectl get pvc -n tfvisualizer
kubectl get secrets -n tfvisualizer
```

### Check for Drift

```bash
# Plan will show any drift
cd terraform
terraform plan

# If drift detected:
terraform apply  # Reconcile
```

---

## 🧹 Cleanup

### Destroy Everything

```bash
cd terraform
terraform destroy
```

**This removes:**
- Entire DOKS cluster
- All databases and data
- Load balancer
- DNS records
- Spaces bucket (if empty)
- SSL certificate

### Partial Cleanup (kubectl)

```bash
# Delete application only
kubectl delete deployment tfvisualizer-app -n tfvisualizer

# Delete databases
kubectl delete statefulset postgres redis -n tfvisualizer

# Delete namespace (removes everything)
kubectl delete namespace tfvisualizer
```

---

## 🔐 Security Best Practices

### Secrets Management

✅ **DO:**
- Store passwords in `terraform.tfvars` (gitignored)
- Use Terraform variables for sensitive data
- Rotate credentials regularly
- Use strong passwords (32+ characters)

❌ **DON'T:**
- Commit `terraform.tfvars` to Git
- Hardcode secrets in `.tf` files
- Use default passwords
- Share credentials in plain text

### State Security

✅ **DO:**
- Use remote state backend (Spaces)
- Encrypt state at rest
- Limit access to state bucket
- Backup state regularly

❌ **DON'T:**
- Store state in Git
- Share state files
- Modify state manually
- Ignore state backups

---

## 📚 File Reference

### Terraform Files

| File | Lines | Purpose |
|------|-------|---------|
| `backend.tf` | 38 | State backend, providers |
| `main.tf` | 80 | VPC, Spaces, SSL, DNS |
| `kubernetes.tf` | 353 | DOKS, App deployment, Services |
| `databases.tf` | 305 | PostgreSQL, Redis StatefulSets |
| `variables.tf` | 229 | Input variables |
| `outputs.tf` | 95 | Output values |
| `setup.sh` | 118 | Setup script |

**Total:** ~1,218 lines of Terraform code

### YAML Files (Reference Only)

| File | Lines | Terraform Equivalent |
|------|-------|---------------------|
| `namespace.yaml` | 8 | `kubernetes.tf:31-40` |
| `postgres.yaml` | 104 | `databases.tf:2-147` |
| `redis.yaml` | 95 | `databases.tf:149-291` |
| `deployment.yaml` | 126 | `kubernetes.tf:90-308` |
| `secrets.yaml.example` | 56 | `kubernetes.tf:42-88`, `databases.tf:293-305` |

**Total:** ~389 lines of YAML (for reference)

---

## 🎓 Learning Resources

### Terraform
- [Terraform Kubernetes Provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)
- [Terraform State](https://www.terraform.io/docs/state/index.html)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)

### Kubernetes
- [StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [Services](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)

### DigitalOcean
- [DOKS](https://docs.digitalocean.com/products/kubernetes/)
- [Spaces](https://docs.digitalocean.com/products/spaces/)
- [Block Storage](https://docs.digitalocean.com/products/volumes/)

---

## 🔗 Related Documentation

- [KUBERNETES_DEPLOYMENT.md](KUBERNETES_DEPLOYMENT.md) - Complete Kubernetes guide
- [YAML_TO_TERRAFORM_MAPPING.md](YAML_TO_TERRAFORM_MAPPING.md) - YAML → Terraform conversion
- [DATABASE_ARCHITECTURE.md](DATABASE_ARCHITECTURE.md) - Database setup and management
- [GHCR_SETUP.md](GHCR_SETUP.md) - Container registry configuration
- [k8s/TERRAFORM_NOTE.md](k8s/TERRAFORM_NOTE.md) - Why YAML files are reference only

---

**All infrastructure is defined as code. Deploy with confidence using Terraform.**
