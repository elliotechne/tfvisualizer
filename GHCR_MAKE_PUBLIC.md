# Make GHCR Package Public - Step by Step

## Issue

Kubernetes cannot pull Docker image from GitHub Container Registry:

```
failed to authorize: failed to fetch oauth token: unexpected status from GET request to
https://ghcr.io/token?scope=repository%3Aelliotechne%2Ftfvisualizer%3Apull&service=ghcr.io: 403 Forbidden
```

**Root Cause:** The package `ghcr.io/elliotechne/tfvisualizer` is **private** and requires authentication.

---

## Solution 1: Make Package Public (RECOMMENDED)

This is the simplest and most reliable solution for open-source projects.

### Step-by-Step Instructions

#### 1. Navigate to Your Package

Go to: **https://github.com/elliotechne/tfvisualizer/pkgs/container/tfvisualizer**

Or navigate manually:
- Go to your GitHub profile: https://github.com/elliotechne
- Click "Packages" tab
- Click on "tfvisualizer" package

#### 2. Open Package Settings

- On the right sidebar, click **"Package settings"**

#### 3. Change Visibility

- Scroll down to the **"Danger Zone"** section (bottom of page)
- Click **"Change visibility"** button
- Select **"Public"**
- Type `tfvisualizer` (or the full package name) to confirm
- Click **"I understand, change package visibility"**

#### 4. Verify It's Public

Test by pulling without authentication:

```bash
docker pull ghcr.io/elliotechne/tfvisualizer:latest
```

If this succeeds without login, the package is now public ✅

---

## Why Make It Public?

### Benefits:
- ✅ **No authentication needed** - Kubernetes can pull directly
- ✅ **Faster deployments** - No token validation overhead
- ✅ **Easier debugging** - Anyone can pull and test
- ✅ **Better for open-source** - Matches project visibility
- ✅ **No token expiration issues** - No credential management

### Drawbacks:
- ⚠️ Anyone can pull your Docker image (but source code is already public)
- ⚠️ Package appears in public listings

**For open-source projects, making packages public is standard practice.**

---

## Solution 2: Use Personal Access Token (If Must Stay Private)

If your package needs to remain private, follow these steps:

### Step 1: Create Personal Access Token

1. **Go to:** https://github.com/settings/tokens/new

2. **Configure token:**
   - **Note:** `GHCR Pull Token for tfvisualizer`
   - **Expiration:** 90 days (or No expiration for production)
   - **Select scopes:**
     - ✅ `read:packages` - Download packages from GitHub Package Registry
     - ✅ `write:packages` - Upload packages to GitHub Package Registry

3. **Generate token** and copy it (starts with `ghp_`)

### Step 2: Add Token to GitHub Secrets

1. **Go to:** https://github.com/elliotechne/tfvisualizer/settings/secrets/actions

2. **Click:** "New repository secret"

3. **Add secret:**
   - **Name:** `GHCR_PAT`
   - **Value:** Paste your token (ghp_xxxxx...)
   - **Click:** "Add secret"

### Step 3: Update Workflow to Use PAT

Edit `.github/workflows/terraform.yml`:

**Find line 44:**
```yaml
TF_VAR_docker_registry_password: ${{ secrets.GITHUB_TOKEN }}
```

**Replace with:**
```yaml
TF_VAR_docker_registry_password: ${{ secrets.GHCR_PAT }}
```

### Step 4: Update Terraform Variables

If deploying locally (outside GitHub Actions), create `terraform/terraform.tfvars`:

```hcl
# Copy from terraform.tfvars.example
docker_registry          = "ghcr.io"
docker_image             = "elliotechne/tfvisualizer"
docker_tag               = "latest"
docker_registry_username = "elliotechne"
docker_registry_password = "ghp_your_personal_access_token_here"  # Your PAT
docker_registry_email    = "your-email@example.com"
```

**Important:** Add `terraform.tfvars` to `.gitignore` to prevent committing credentials!

---

## Verification

### Test Authentication Locally

```bash
# Login to GHCR
echo "YOUR_TOKEN" | docker login ghcr.io -u elliotechne --password-stdin

# Expected output:
# Login Succeeded

# Pull image
docker pull ghcr.io/elliotechne/tfvisualizer:latest

# Expected output:
# latest: Pulling from elliotechne/tfvisualizer
# Status: Downloaded newer image for ghcr.io/elliotechne/tfvisualizer:latest
```

### Test in Kubernetes

After Terraform apply:

```bash
# Check pod status
kubectl get pods -n tfvisualizer

# Expected: Pod should be Running (not ImagePullBackOff)

# Check events
kubectl describe pod tfvisualizer-app-xxxxx -n tfvisualizer | grep -A10 Events

# Expected: "Successfully pulled image"
```

---

## Comparison: Public vs Private Package

| Feature | Public Package | Private Package |
|---------|---------------|-----------------|
| **Authentication** | Not required | Required (PAT or token) |
| **Setup Complexity** | Very simple | Moderate |
| **Token Management** | None | Need to rotate tokens |
| **Pull Speed** | Faster | Slightly slower |
| **Visibility** | Anyone can see | Only authenticated users |
| **Cost** | Free | Free (for public repos) |
| **Best For** | Open-source projects | Private/proprietary code |

---

## Troubleshooting

### Still Getting 403 After Making Public

**Wait a few minutes** - GitHub can take up to 5 minutes to propagate visibility changes.

**Clear cache:**
```bash
docker system prune -a
docker pull ghcr.io/elliotechne/tfvisualizer:latest
```

### PAT Not Working

**Check token scopes:**
1. Go to: https://github.com/settings/tokens
2. Find your token
3. Verify it has `read:packages` and `write:packages` scopes
4. If not, create a new token with correct scopes

**Check token expiration:**
- Tokens can expire
- Create new token if expired

**Check username:**
- Username must be `elliotechne` (lowercase)
- Not your email or display name

### Secret Not Updated in Kubernetes

**After changing token in GitHub Secrets:**

```bash
# Delete existing secret
kubectl delete secret docker-registry-credentials -n tfvisualizer

# Re-run Terraform to recreate with new token
cd terraform
terraform apply -auto-approve

# Restart pods to use new secret
kubectl rollout restart deployment/tfvisualizer-app -n tfvisualizer
```

---

## Recommended Approach

**For this project, we recommend:**

### ✅ Make Package Public

**Reasons:**
1. Source code is already public on GitHub
2. Simpler deployment (no credentials)
3. Standard practice for open-source projects
4. No token expiration issues
5. Anyone can test/contribute easily

**Examples of public packages:**
- Docker Hub: Most official images are public
- GHCR: Popular OSS projects use public packages
- NPM, PyPI: Public by default

---

## Quick Commands

### Make Package Public (after doing so in UI):

```bash
# Test it worked
docker pull ghcr.io/elliotechne/tfvisualizer:latest

# Should succeed without docker login
```

### Use PAT (if keeping private):

```bash
# Create token at: https://github.com/settings/tokens/new
# Add to secrets at: https://github.com/elliotechne/tfvisualizer/settings/secrets/actions

# Update workflow file
sed -i 's/GITHUB_TOKEN/GHCR_PAT/g' .github/workflows/terraform.yml

# Commit and push
git add .github/workflows/terraform.yml
git commit -m "Use PAT for GHCR authentication"
git push
```

---

## Summary

**Current Status:** Package is private ❌

**Recommended Fix:** Make package public ✅

**Steps:**
1. Go to https://github.com/elliotechne/tfvisualizer/pkgs/container/tfvisualizer
2. Click "Package settings"
3. Change visibility to "Public"
4. Test: `docker pull ghcr.io/elliotechne/tfvisualizer:latest`

**Result:** Kubernetes will be able to pull the image without authentication ✅

---

**Make package public to resolve authentication error. ✅**
