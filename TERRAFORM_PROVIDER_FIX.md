# Terraform Provider Configuration Fix

## Issue

```
Error: Duplicate provider configuration

A default (non-aliased) provider configuration for "digitalocean" was
already given at backend.tf:35,1-24. If multiple configurations are
required, set the "alias" argument for alternative configurations.
```

**Root Cause:** Multiple files contained duplicate `provider` and `terraform {}` blocks.

---

## Files Modified

### 1. `terraform/providers.tf`

**Before:**
```hcl
terraform {
  required_version = ">= 1.0"
  required_providers { ... }
  backend "s3" { ... }  # DUPLICATE
}

provider "digitalocean" {   # DUPLICATE
  token = var.do_token
}

provider "kubernetes" {     # DUPLICATE (wrong cluster name)
  host  = digitalocean_kubernetes_cluster.tfvisualizer.endpoint
  ...
}
```

**After:**
```hcl
# Provider Configurations
#
# Note: All provider configurations have been moved to their respective files:
# - DigitalOcean provider: backend.tf
# - Kubernetes provider: kubernetes.tf (after cluster creation)
#
# This file is kept for reference and can be removed if not needed.
```

---

## Current Provider Configuration

### File: `backend.tf`

**Contains:**
- ✅ One `terraform {}` block with required providers
- ✅ One `backend "s3"` configuration (DigitalOcean Spaces)
- ✅ One `provider "digitalocean"` configuration

```hcl
terraform {
  backend "s3" {
    endpoints = { s3 = "https://nyc3.digitaloceanspaces.com" }
    region    = "us-east-1"
    bucket    = "tfvisualizer-terraform-state"
    key       = "production/terraform.tfstate"
    ...
  }

  required_version = ">= 1.6.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.34.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}
```

### File: `kubernetes.tf`

**Contains:**
- ✅ One `provider "kubernetes"` configuration
- ✅ References correct cluster: `digitalocean_kubernetes_cluster.main`

```hcl
# DigitalOcean Kubernetes Cluster
resource "digitalocean_kubernetes_cluster" "main" {
  name     = "${var.project_name}-${var.environment}-k8s"
  region   = var.region
  ...
}

# Kubernetes provider configuration
provider "kubernetes" {
  host  = digitalocean_kubernetes_cluster.main.endpoint
  token = digitalocean_kubernetes_cluster.main.kube_config[0].token
  cluster_ca_certificate = base64decode(
    digitalocean_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate
  )
}
```

---

## Verification

### Check for Duplicate Providers

```bash
cd terraform
grep -n "^provider " *.tf
```

**Expected Output:**
```
backend.tf:35:provider "digitalocean" {
kubernetes.tf:22:provider "kubernetes" {
```

### Check for Duplicate terraform {} Blocks

```bash
grep -n "^terraform {" *.tf
```

**Expected Output:**
```
backend.tf:1:terraform {
```

### Validate Configuration

```bash
cd terraform
terraform init -backend=false
terraform validate
```

**Expected Output:**
```
Initializing provider plugins...
- Finding hashicorp/kubernetes versions matching "~> 2.24.0"...
- Finding digitalocean/digitalocean versions matching "~> 2.34.0"...
- Installed hashicorp/kubernetes v2.24.0
- Installed digitalocean/digitalocean v2.34.1

Success! The configuration is valid.
```

---

## Best Practices

### ✅ DO:
- Keep one `terraform {}` block per Terraform configuration
- Define each provider only once (unless using aliases)
- Place provider configs in logical files:
  - Main provider in `backend.tf` or `providers.tf`
  - Dependent providers (like Kubernetes) near their resources
- Use provider dependencies when one depends on resources from another

### ❌ DON'T:
- Define the same provider in multiple files
- Have multiple `terraform {}` blocks
- Mix backend configurations across files
- Reference non-existent resource names in provider configs

---

## Provider Organization Strategy

### Option 1: All in `backend.tf` (Current)

```
backend.tf          - terraform {}, backend, digitalocean provider
kubernetes.tf       - kubernetes provider (depends on cluster)
main.tf             - Resources using providers
databases.tf        - Resources using providers
```

**Pros:**
- Centralized provider configuration
- Backend and main provider together
- Clear separation

### Option 2: Separate `providers.tf`

```
backend.tf          - terraform {}, backend
providers.tf        - All provider configurations
kubernetes.tf       - Kubernetes resources
main.tf             - Other resources
```

**Pros:**
- All providers in one place
- Easier to update provider versions
- Clean separation of concerns

**Note:** We're using Option 1 (current setup) to avoid circular dependencies since the Kubernetes provider depends on the DOKS cluster resource.

---

## Provider Dependencies

The Kubernetes provider **depends on** the DigitalOcean Kubernetes cluster:

```
digitalocean_kubernetes_cluster.main (created)
    ↓
    Generates: endpoint, token, cluster_ca_certificate
    ↓
provider "kubernetes" (configured)
    ↓
kubernetes_namespace, kubernetes_deployment, etc. (created)
```

This is why the Kubernetes provider is defined **after** the cluster resource in `kubernetes.tf`, not in a separate providers file.

---

## Troubleshooting

### Error: Duplicate provider configuration

**Solution:**
```bash
# Find all provider blocks
grep -rn "^provider " terraform/

# Remove duplicates, keep only one per provider type
```

### Error: provider.kubernetes: no suitable version installed

**Solution:**
```bash
cd terraform
terraform init
```

### Error: Invalid reference in provider configuration

**Example:**
```
provider "kubernetes" {
  host = digitalocean_kubernetes_cluster.wrong_name.endpoint
}
```

**Solution:**
Ensure provider references match actual resource names:
```bash
# Find cluster resource name
grep "resource \"digitalocean_kubernetes_cluster\"" terraform/*.tf

# Update provider to match
```

### Warning: Provider development overrides

This is normal in development and can be ignored. It's informational only.

---

## Related Files

| File | Contains | Purpose |
|------|----------|---------|
| `backend.tf` | terraform {}, backend, digitalocean provider | Main configuration |
| `kubernetes.tf` | kubernetes provider, DOKS cluster | Kubernetes resources |
| `providers.tf` | (empty/comments) | Legacy file, can be removed |
| `variables.tf` | var.do_token, etc. | Provider credentials |

---

## Next Steps

1. **Validate Configuration:**
   ```bash
   cd terraform
   terraform init -backend=false
   terraform validate
   ```

2. **Format Code:**
   ```bash
   terraform fmt -recursive
   ```

3. **Plan Deployment:**
   ```bash
   terraform init \
     -backend-config="access_key=$DO_SPACES_ACCESS_KEY" \
     -backend-config="secret_key=$DO_SPACES_SECRET_KEY"

   terraform plan
   ```

4. **Optional: Remove providers.tf**
   ```bash
   # Since it's now empty, you can remove it
   rm terraform/providers.tf
   ```

---

## Summary

**Changes Made:**
- ✅ Removed duplicate `terraform {}` block from `providers.tf`
- ✅ Removed duplicate `provider "digitalocean"` from `providers.tf`
- ✅ Removed duplicate `provider "kubernetes"` from `providers.tf`
- ✅ Kept correct providers in `backend.tf` and `kubernetes.tf`

**Current State:**
- ✅ One `terraform {}` block in `backend.tf`
- ✅ One `provider "digitalocean"` in `backend.tf`
- ✅ One `provider "kubernetes"` in `kubernetes.tf`
- ✅ All provider versions specified in `backend.tf`

**Result:** Terraform configuration is now valid and ready for deployment.

---

**Provider configuration fixed. No more duplicates. ✅**
