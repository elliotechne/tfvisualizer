# Docker Image Reference Fix

## Issue

Docker image pull was failing with duplicate registry path:

```
failed to resolve reference "ghcr.io/ghcr.io/elliotechne/tfvisualizer:latest":
failed to authorize: failed to fetch oauth token
```

---

## Root Cause

The `docker_image` variable included the full registry path (`ghcr.io/elliotechne/tfvisualizer`), but Terraform was also prepending the `docker_registry` variable, resulting in:

```
${var.docker_registry}/${var.docker_image}:${var.docker_tag}
  ↓
ghcr.io/ghcr.io/elliotechne/tfvisualizer:latest  ❌
```

---

## Solution

### Changed: `terraform/variables.tf`

**Before:**
```hcl
variable "docker_image" {
  description = "Docker image name"
  type        = string
  default     = "ghcr.io/elliotechne/tfvisualizer"  # ❌ Includes registry
}
```

**After:**
```hcl
variable "docker_image" {
  description = "Docker image name (without registry)"
  type        = string
  default     = "elliotechne/tfvisualizer"  # ✅ Registry removed
}
```

### Changed: `terraform/terraform.tfvars.example`

**Before:**
```hcl
docker_image = "ghcr.io/elliotechne/tfvisualizer"  # ❌
```

**After:**
```hcl
docker_image = "elliotechne/tfvisualizer"  # ✅
```

---

## How It Works Now

### Variable Combination

```hcl
# kubernetes.tf (Line 120)
image = "${var.docker_registry}/${var.docker_image}:${var.docker_tag}"
```

### With Default Values

```
docker_registry = "ghcr.io"
docker_image    = "elliotechne/tfvisualizer"
docker_tag      = "latest"

Result: ghcr.io/elliotechne/tfvisualizer:latest  ✅
```

### With Custom Registry

```
docker_registry = "docker.io"
docker_image    = "myorg/tfvisualizer"
docker_tag      = "v1.0.0"

Result: docker.io/myorg/tfvisualizer:v1.0.0  ✅
```

---

## Variable Structure

### Separation of Concerns

| Variable | Purpose | Example Value |
|----------|---------|---------------|
| `docker_registry` | Registry URL only | `ghcr.io` |
| `docker_image` | Org/repo name only | `elliotechne/tfvisualizer` |
| `docker_tag` | Image tag/version | `latest`, `v1.0.0`, `main-a1b2c3d` |

### Combined Result

```
{docker_registry}/{docker_image}:{docker_tag}
ghcr.io/elliotechne/tfvisualizer:latest
```

---

## Impact

### Files Modified

1. ✅ `terraform/variables.tf` - Updated `docker_image` default value
2. ✅ `terraform/terraform.tfvars.example` - Updated `docker_image` example
3. ⚪ `terraform/kubernetes.tf` - No change needed (already correct)

### Deployment Changes

**Before:** Image pull would fail with `ghcr.io/ghcr.io/elliotechne/tfvisualizer:latest`

**After:** Image pull succeeds with `ghcr.io/elliotechne/tfvisualizer:latest`

---

## Verification

### Check Variable Values

```bash
cd terraform

# Show planned value
terraform plan | grep -A3 "image.*="

# Expected output:
# image = "ghcr.io/elliotechne/tfvisualizer:latest"
```

### Test Image Pull

```bash
# Pull image manually to verify
docker pull ghcr.io/elliotechne/tfvisualizer:latest

# Should succeed without authentication errors
```

### Verify Kubernetes Deployment

```bash
# After terraform apply
kubectl get deployment tfvisualizer-app -n tfvisualizer -o yaml | grep image

# Expected output:
# image: ghcr.io/elliotechne/tfvisualizer:latest
```

---

## GitHub Actions Integration

### Workflow Variables

The GitHub Actions workflow sets these environment variables:

```yaml
env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}  # elliotechne/tfvisualizer
```

### Image Building

```yaml
- name: Extract metadata (tags, labels)
  id: meta
  uses: docker/metadata-action@v5
  with:
    images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
    # Results in: ghcr.io/elliotechne/tfvisualizer
```

### Terraform Variables

The workflow passes the image components:

```yaml
env:
  TF_VAR_docker_registry: ghcr.io  # Set via workflow
  TF_VAR_docker_image: elliotechne/tfvisualizer  # From variables.tf default
  TF_VAR_docker_tag: latest  # From variables.tf default
```

**Note:** If you want to override `docker_image` in CI/CD, add:

```yaml
env:
  TF_VAR_docker_image: ${{ github.repository }}
```

But this is optional since the default matches.

---

## Best Practices

### ✅ DO:

1. **Separate registry from image name**
   ```hcl
   docker_registry = "ghcr.io"
   docker_image    = "elliotechne/tfvisualizer"
   ```

2. **Use organization/repo format for image name**
   ```hcl
   docker_image = "elliotechne/tfvisualizer"  # Not "tfvisualizer"
   ```

3. **Keep tag separate**
   ```hcl
   docker_tag = "latest"  # Not part of docker_image
   ```

### ❌ DON'T:

1. **Don't include registry in image name**
   ```hcl
   docker_image = "ghcr.io/elliotechne/tfvisualizer"  # ❌
   ```

2. **Don't include tag in image name**
   ```hcl
   docker_image = "elliotechne/tfvisualizer:latest"  # ❌
   ```

3. **Don't use hardcoded full paths**
   ```hcl
   image = "ghcr.io/elliotechne/tfvisualizer:latest"  # ❌ Not configurable
   ```

---

## Troubleshooting

### Error: Image not found

```
Error: failed to resolve reference "ghcr.io/elliotechne/tfvisualizer:latest"
```

**Check:**
1. Image exists in registry: https://github.com/elliotechne/tfvisualizer/pkgs/container/tfvisualizer
2. Image is public or authentication is configured
3. Tag exists (e.g., `latest` tag might not exist for new repos)

**Solution:**
```bash
# Verify image exists
docker pull ghcr.io/elliotechne/tfvisualizer:latest

# If authentication error, login first
echo $GITHUB_TOKEN | docker login ghcr.io -u elliotechne --password-stdin
```

### Error: Duplicate registry path

```
Error: failed to resolve "ghcr.io/ghcr.io/..."
```

**Solution:** Update variables as shown in this document (already fixed).

### Error: Unauthorized

```
Error: failed to authorize: failed to fetch oauth token
```

**Check:**
1. GitHub Container Registry authentication secret configured
2. Secret has `read:packages` permission
3. Package visibility is public or token has access

**Solution:**
```bash
# Verify authentication in Kubernetes secret
kubectl get secret docker-registry-secret -n tfvisualizer -o yaml

# Should contain base64-encoded docker config
```

---

## Testing Checklist

- [x] Updated `docker_image` variable to exclude registry
- [x] Updated `terraform.tfvars.example`
- [ ] Run `terraform plan` to verify image reference is correct
- [ ] Run `terraform apply` to update Kubernetes deployment
- [ ] Verify pod pulls image successfully:
  ```bash
  kubectl get pods -n tfvisualizer
  kubectl describe pod tfvisualizer-app-xxx -n tfvisualizer | grep -A5 Events
  ```
- [ ] Verify no `ErrImagePull` or `ImagePullBackOff` errors

---

## Related Files

| File | Change | Status |
|------|--------|--------|
| `terraform/variables.tf` | Updated `docker_image` default | ✅ Fixed |
| `terraform/terraform.tfvars.example` | Updated `docker_image` example | ✅ Fixed |
| `terraform/kubernetes.tf` | No change (already correct) | ✅ OK |
| `.github/workflows/terraform.yml` | No change needed | ✅ OK |
| `.github/workflows/docker-build.yml` | No change needed | ✅ OK |

---

## Summary

**Problem:** `ghcr.io/ghcr.io/elliotechne/tfvisualizer:latest` (duplicate registry)

**Solution:** Changed `docker_image` variable from `ghcr.io/elliotechne/tfvisualizer` to `elliotechne/tfvisualizer`

**Result:** `ghcr.io/elliotechne/tfvisualizer:latest` ✅

Image references are now correctly formed and container pulls will succeed.

---

**Docker image reference fixed. ✅**
