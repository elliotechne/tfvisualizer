# GitHub Container Registry Authentication Fix

## Issue

Kubernetes unable to pull Docker image from GitHub Container Registry (GHCR):

```
failed to authorize: failed to fetch oauth token: unexpected status from GET request to
https://ghcr.io/token?scope=repository%3Aelliotechne%2Ftfvisualizer%3Apull&service=ghcr.io: 403 Forbidden
```

---

## Root Causes

### 1. **Missing `packages: read` Permission**

The `terraform-apply` job was missing the `packages: read` permission, preventing it from passing a valid token to Terraform that can pull packages from GHCR.

### 2. **Package Visibility**

The GitHub Container Registry package might be private, requiring authentication to pull.

### 3. **Token Scope**

The `GITHUB_TOKEN` used in the workflow needs both:
- `read:packages` - to read from GHCR
- `write:packages` - to push to GHCR (already configured in `build-and-push` job)

---

## Solution

### 1. Add Permissions to `terraform-apply` Job

**File:** `.github/workflows/terraform.yml`

**Before:**
```yaml
terraform-apply:
  name: Apply Terraform Changes
  runs-on: ubuntu-latest
  needs: [build-and-push, terraform-plan]
  if: github.ref == 'refs/heads/main' && github.event_name == 'push'
  environment:
    name: production
    url: https://tfvisualizer.com
```

**After:**
```yaml
terraform-apply:
  name: Apply Terraform Changes
  runs-on: ubuntu-latest
  needs: [build-and-push, terraform-plan]
  if: github.ref == 'refs/heads/main' && github.event_name == 'push'
  permissions:
    contents: read
    packages: read  # ✅ Added - allows reading from GHCR
  environment:
    name: production
    url: https://tfvisualizer.com
```

### 2. Make Package Public (Recommended)

Since this is a public project, making the package public eliminates authentication issues:

1. **Navigate to package:**
   - Go to: https://github.com/users/elliotechne/packages/container/tfvisualizer/settings
   - Or: GitHub profile → Packages → tfvisualizer → Package settings

2. **Change visibility:**
   - Scroll to "Danger Zone"
   - Click "Change visibility"
   - Select "Public"
   - Confirm

**Benefits of public packages:**
- ✅ No authentication required for pulls
- ✅ Faster deployments (no token validation)
- ✅ Works with any Kubernetes cluster
- ✅ Easier testing and debugging

### 3. Use Personal Access Token (Alternative)

If the package must remain private, use a Personal Access Token (PAT) instead of `GITHUB_TOKEN`:

**Create PAT:**
1. Go to: https://github.com/settings/tokens/new
2. Select scopes:
   - ✅ `read:packages`
   - ✅ `write:packages`
3. Generate token
4. Add to repository secrets as `GHCR_PAT`

**Update workflow:**
```yaml
env:
  TF_VAR_docker_registry_username: ${{ github.actor }}
  TF_VAR_docker_registry_password: ${{ secrets.GHCR_PAT }}  # Changed from GITHUB_TOKEN
```

---

## How Kubernetes Pulls Images

### Authentication Flow

1. **Terraform creates Kubernetes secret:**
   ```hcl
   resource "kubernetes_secret" "docker_registry" {
     type = "kubernetes.io/dockerconfigjson"
     data = {
       ".dockerconfigjson" = jsonencode({
         auths = {
           "ghcr.io" = {
             username = var.docker_registry_username
             password = var.docker_registry_password
             auth     = base64encode("${username}:${password}")
           }
         }
       })
     }
   }
   ```

2. **Deployment references secret:**
   ```hcl
   spec {
     image_pull_secrets {
       name = kubernetes_secret.docker_registry.metadata[0].name
     }
   }
   ```

3. **Kubernetes uses secret to authenticate:**
   - Kubernetes reads `.dockerconfigjson` from secret
   - Sends credentials to GHCR when pulling image
   - GHCR validates token and returns image

---

## Verification Steps

### 1. Check Package Visibility

```bash
# Try pulling image without authentication
docker pull ghcr.io/elliotechne/tfvisualizer:latest

# If this fails with 403, package is private
# If it succeeds, package is public ✅
```

### 2. Test Token Permissions

```bash
# Test if GITHUB_TOKEN can read packages
echo $GITHUB_TOKEN | docker login ghcr.io -u elliotechne --password-stdin

docker pull ghcr.io/elliotechne/tfvisualizer:latest

# If this succeeds, token has correct permissions ✅
```

### 3. Verify Kubernetes Secret

After Terraform applies:

```bash
# Get kubeconfig
export KUBECONFIG=~/path/to/kubeconfig.yaml

# Check if secret exists
kubectl get secret docker-registry-credentials -n tfvisualizer

# View secret contents (base64 encoded)
kubectl get secret docker-registry-credentials -n tfvisualizer -o yaml

# Decode and view dockerconfigjson
kubectl get secret docker-registry-credentials -n tfvisualizer -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq
```

Expected output:
```json
{
  "auths": {
    "ghcr.io": {
      "username": "elliotechne",
      "password": "ghp_...",
      "email": "your-email@example.com",
      "auth": "ZWxsaW90ZWNobmU6Z2hwXy4uLg=="
    }
  }
}
```

### 4. Check Pod Events

```bash
# List pods
kubectl get pods -n tfvisualizer

# Describe pod to see pull errors
kubectl describe pod tfvisualizer-app-xxxx -n tfvisualizer | grep -A10 Events

# Check for ImagePullBackOff or ErrImagePull
kubectl get pods -n tfvisualizer -o wide
```

**Success indicators:**
- Pod status: `Running`
- No `ImagePullBackOff` errors
- Events show: `Successfully pulled image`

**Failure indicators:**
- Pod status: `ImagePullBackOff` or `ErrImagePull`
- Events show: `failed to authorize` or `403 Forbidden`

---

## Troubleshooting

### Error: 403 Forbidden (Package is Private)

**Solution 1: Make package public** (recommended for public projects)
- Go to package settings
- Change visibility to Public

**Solution 2: Use PAT with correct scopes**
- Create PAT with `read:packages` and `write:packages`
- Add to GitHub Secrets as `GHCR_PAT`
- Update workflow to use `secrets.GHCR_PAT`

### Error: Invalid Username or Password

**Check:**
1. Username is correct (`elliotechne`)
2. Password/token is valid and not expired
3. Token has `read:packages` scope

**Fix:**
```bash
# Test login manually
echo "YOUR_TOKEN" | docker login ghcr.io -u elliotechne --password-stdin

# If this fails, token is invalid
```

### Error: Secret Not Found

**Check:**
```bash
kubectl get secret docker-registry-credentials -n tfvisualizer
```

**If missing:**
- Terraform didn't apply correctly
- Run `terraform apply` again
- Check Terraform outputs for errors

### Error: Wrong Secret Format

**Check secret type:**
```bash
kubectl get secret docker-registry-credentials -n tfvisualizer -o yaml | grep type
```

**Should be:**
```yaml
type: kubernetes.io/dockerconfigjson
```

**If wrong type, delete and recreate:**
```bash
kubectl delete secret docker-registry-credentials -n tfvisualizer
terraform apply -auto-approve
```

---

## GitHub Actions Environment Variables

The workflow passes Docker registry credentials to Terraform via environment variables:

```yaml
env:
  # Docker Registry Configuration
  TF_VAR_docker_registry_username: ${{ github.actor }}          # "elliotechne"
  TF_VAR_docker_registry_password: ${{ secrets.GITHUB_TOKEN }}  # Token with packages:read
  TF_VAR_docker_registry_email: ${{ secrets.DOCKER_REGISTRY_EMAIL }}
```

### Required GitHub Secrets

| Secret | Description | Example Value |
|--------|-------------|---------------|
| `GITHUB_TOKEN` | Automatically provided by GitHub Actions | `ghp_...` (auto) |
| `DOCKER_REGISTRY_EMAIL` | Email for Docker registry | `your-email@example.com` |

**Optional (if using PAT):**
| Secret | Description | Example Value |
|--------|-------------|---------------|
| `GHCR_PAT` | Personal Access Token with `read:packages` | `ghp_xxxxx...` |

---

## Permissions Summary

### Job Permissions in Workflow

| Job | Permissions Needed | Reason |
|-----|-------------------|--------|
| `build-and-push` | `packages: write` | Push Docker image to GHCR |
| `terraform-validate` | None | Only validates syntax |
| `terraform-plan` | None | Only plans changes |
| `terraform-apply` | `packages: read` | Passes token to Terraform for Kubernetes secret |
| `terraform-destroy` | None | Only destroys resources |

### Token Scopes

| Scope | Required For |
|-------|-------------|
| `read:packages` | Pulling images from GHCR |
| `write:packages` | Pushing images to GHCR |

---

## Best Practices

### ✅ DO:

1. **Use public packages for public projects**
   - Eliminates authentication complexity
   - Faster deployments
   - Easier to debug

2. **Set proper job permissions**
   - Only grant permissions jobs actually need
   - Use `packages: read` for jobs that pull images
   - Use `packages: write` for jobs that push images

3. **Use PAT for private packages**
   - More reliable than `GITHUB_TOKEN`
   - Can have longer expiration
   - Fine-grained control

4. **Test authentication locally**
   ```bash
   echo $TOKEN | docker login ghcr.io -u username --password-stdin
   docker pull ghcr.io/elliotechne/tfvisualizer:latest
   ```

### ❌ DON'T:

1. **Don't use `GITHUB_TOKEN` for private packages in long-running workflows**
   - Short-lived (expires after job)
   - Limited to repository scope

2. **Don't commit credentials**
   - Always use GitHub Secrets
   - Never hardcode tokens in Terraform files

3. **Don't use overly permissive tokens**
   - Only grant necessary scopes
   - Avoid tokens with `repo` or `admin:org` if not needed

---

## Testing Checklist

- [x] Added `packages: read` permission to `terraform-apply` job
- [ ] Verify package visibility (public vs private)
- [ ] Test image pull without authentication (if public)
- [ ] Check Kubernetes secret exists after Terraform apply
- [ ] Verify pod can pull image successfully
- [ ] Confirm no `ImagePullBackOff` errors
- [ ] Check pod logs for application startup

---

## Quick Fix Command

If you need to manually test/fix the Kubernetes secret:

```bash
# Delete existing secret
kubectl delete secret docker-registry-credentials -n tfvisualizer

# Create new secret manually
kubectl create secret docker-registry docker-registry-credentials \
  --docker-server=ghcr.io \
  --docker-username=elliotechne \
  --docker-password="YOUR_TOKEN_HERE" \
  --docker-email="your-email@example.com" \
  -n tfvisualizer

# Restart deployment to use new secret
kubectl rollout restart deployment/tfvisualizer-app -n tfvisualizer

# Watch rollout status
kubectl rollout status deployment/tfvisualizer-app -n tfvisualizer --watch
```

---

## Related Documentation

- [GitHub Packages Documentation](https://docs.github.com/en/packages)
- [GHCR Authentication](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [Kubernetes imagePullSecrets](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/)
- [GitHub Actions Permissions](https://docs.github.com/en/actions/security-guides/automatic-token-authentication#permissions-for-the-github_token)

---

## Summary

**Problem:** 403 Forbidden when Kubernetes tries to pull image from GHCR

**Root Cause:** `terraform-apply` job missing `packages: read` permission

**Solution:** Added `packages: read` permission to workflow ✅

**Next Steps:**
1. Make package public (recommended)
2. Or verify token has `read:packages` scope
3. Run workflow and verify pod pulls image successfully

---

**GHCR authentication configured. ✅**
