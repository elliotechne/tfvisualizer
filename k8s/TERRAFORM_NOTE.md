# Kubernetes YAML Files - Reference Only

⚠️ **Important**: The YAML files in this directory are for **reference and manual deployment only**.

---

## 🎯 Primary Deployment Method: Terraform

All Kubernetes resources are defined in Terraform code in the `../terraform/` directory:

### Terraform Files

| Terraform File | What It Contains |
|---------------|------------------|
| `terraform/kubernetes.tf` | Namespace, Deployment, Service, HPA, PDB, NetworkPolicy, Secrets, ConfigMaps |
| `terraform/databases.tf` | PostgreSQL StatefulSet, Redis StatefulSet, Services, Database Credentials |
| `terraform/main.tf` | VPC, Spaces, SSL Certificate, DNS, Project |

### Why Use Terraform?

✅ **Infrastructure as Code**: Version controlled, reviewable changes
✅ **Automated Deployment**: CI/CD integration with GitHub Actions
✅ **State Management**: Knows what's deployed, prevents drift
✅ **Dependency Management**: Handles resource dependencies automatically
✅ **Integrated**: Creates everything (DOKS cluster, DNS, SSL, databases, app)

---

## 📋 YAML Files Mapping to Terraform

### namespace.yaml → terraform/kubernetes.tf

```hcl
resource "kubernetes_namespace" "tfvisualizer" {
  # Lines 31-40 in kubernetes.tf
}
```

### postgres.yaml → terraform/databases.tf

```hcl
resource "kubernetes_stateful_set" "postgres" {
  # Lines 2-120 in databases.tf
}

resource "kubernetes_service" "postgres" {
  # Lines 122-147 in databases.tf
}

resource "kubernetes_secret" "database_credentials" {
  # Lines 293-305 in databases.tf
}
```

### redis.yaml → terraform/databases.tf

```hcl
resource "kubernetes_stateful_set" "redis" {
  # Lines 149-264 in databases.tf
}

resource "kubernetes_service" "redis" {
  # Lines 266-291 in databases.tf
}
```

### deployment.yaml → terraform/kubernetes.tf

```hcl
# Deployment
resource "kubernetes_deployment" "app" {
  # Lines 90-188 in kubernetes.tf
}

# Service (LoadBalancer)
resource "kubernetes_service" "app" {
  # Lines 190-227 in kubernetes.tf
}

# HorizontalPodAutoscaler
resource "kubernetes_horizontal_pod_autoscaler_v2" "app" {
  # Lines 229-268 in kubernetes.tf
}

# PodDisruptionBudget
resource "kubernetes_pod_disruption_budget_v1" "app" {
  # Lines 293-308 in kubernetes.tf
}
```

### secrets.yaml.example → terraform/kubernetes.tf

```hcl
resource "kubernetes_secret" "app_config" {
  # Lines 42-75 in kubernetes.tf
}

resource "kubernetes_config_map" "app_config" {
  # Lines 77-88 in kubernetes.tf
}

resource "kubernetes_secret" "docker_registry" {
  # Lines 270-291 in kubernetes.tf
}
```

---

## 🚀 Deployment Methods

### Method 1: Terraform (Recommended)

```bash
cd terraform

# Initialize
terraform init \
  -backend-config="access_key=$DO_SPACES_ACCESS_KEY" \
  -backend-config="secret_key=$DO_SPACES_SECRET_KEY"

# Configure
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars

# Deploy everything
terraform apply
```

**This creates:**
- DOKS Kubernetes cluster
- PostgreSQL StatefulSet
- Redis StatefulSet
- Application Deployment
- Load Balancer with SSL
- DNS records
- Spaces bucket
- All secrets and configs

### Method 2: Manual kubectl (YAML files)

Use the YAML files in this directory only if:
- You have an existing Kubernetes cluster
- You want to deploy without Terraform
- You're testing/debugging specific resources

```bash
cd k8s

# Deploy in order
kubectl apply -f namespace.yaml
kubectl apply -f postgres.yaml
kubectl apply -f redis.yaml
kubectl apply -f secrets.yaml  # Create from secrets.yaml.example
kubectl apply -f deployment.yaml
```

⚠️ **Note**: This method doesn't create:
- DOKS cluster (must already exist)
- DNS records
- SSL certificates
- DigitalOcean Spaces bucket

---

## 🔄 Keeping YAML Files in Sync

The YAML files are kept for:
1. **Documentation**: Easy reference for resource structure
2. **Manual deployment**: Quick testing or emergency deployments
3. **Migration**: Moving to/from other clusters

If you make changes to Terraform, consider updating the YAML files:

```bash
# Generate YAML from Terraform (informational only)
terraform show -json | jq '.values.root_module.resources[] | select(.type | startswith("kubernetes_"))'
```

---

## 📚 Quick Reference

### View Current Deployment

```bash
# Via Terraform
cd terraform
terraform show

# Via kubectl
kubectl get all -n tfvisualizer
kubectl get pvc -n tfvisualizer
```

### Update Deployment

```bash
# Via Terraform (recommended)
cd terraform
terraform apply

# Via kubectl
kubectl apply -f k8s/deployment.yaml
```

### Destroy Resources

```bash
# Via Terraform (destroys everything)
cd terraform
terraform destroy

# Via kubectl (keeps cluster)
kubectl delete namespace tfvisualizer
```

---

## 🆚 Comparison

| Feature | Terraform | kubectl + YAML |
|---------|-----------|----------------|
| Create DOKS cluster | ✅ Yes | ❌ No |
| Create DNS/SSL | ✅ Yes | ❌ No |
| State management | ✅ Yes | ❌ No |
| CI/CD integration | ✅ Easy | ⚠️ Manual |
| Version control | ✅ Full | ⚠️ Partial |
| Drift detection | ✅ Yes | ❌ No |
| Resource dependencies | ✅ Automatic | ⚠️ Manual order |
| Rollback | ✅ Easy | ⚠️ Manual |

---

## 💡 Best Practices

1. **Use Terraform for production** - Full automation and state management
2. **Use YAML for testing** - Quick iterations on specific resources
3. **Keep YAML files updated** - Document any Terraform changes
4. **Version control both** - Track changes in Git
5. **Test YAML changes** - Before applying to Terraform

---

## 🔗 Additional Resources

- [Terraform Kubernetes Provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)
- [Converting YAML to Terraform](https://www.terraform.io/docs/providers/kubernetes/guides/getting-started.html)
- [Terraform State Management](https://www.terraform.io/docs/state/index.html)

---

**Use `../terraform/` for deployments. These YAML files are reference only.**
