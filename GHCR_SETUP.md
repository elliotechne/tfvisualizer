# GitHub Container Registry (GHCR) Setup Guide

Complete guide for using GitHub Container Registry with TFVisualizer.

---

## 🎯 Overview

GitHub Container Registry (ghcr.io) provides:
- ✅ **Free unlimited public images**
- ✅ **500MB free private storage** (with GitHub Free)
- ✅ **50GB free private storage** (with GitHub Pro/Team)
- ✅ **Native GitHub integration**
- ✅ **Fine-grained access control**
- ✅ **Built-in vulnerability scanning**
- ✅ **Automatic cleanup policies**

---

## 🔐 Prerequisites

### 1. GitHub Account
Ensure you have a GitHub account with appropriate permissions.

### 2. Repository Setup
Your repository should be configured to allow package creation:
- Go to repository **Settings** → **Actions** → **General**
- Under "Workflow permissions", select:
  - ✅ **Read and write permissions**
  - ✅ **Allow GitHub Actions to create and approve pull requests**

### 3. Package Visibility
By default, packages inherit repository visibility:
- **Public repository** → Public packages
- **Private repository** → Private packages

You can change package visibility independently in package settings.

---

## 🚀 Quick Start

### Method 1: GitHub Actions (Automatic)

The CI/CD workflow automatically builds and pushes images on every commit.

**No manual steps required!** Just push to main branch:

```bash
git add .
git commit -m "Deploy application"
git push origin main
```

GitHub Actions will:
1. Build Docker image
2. Push to ghcr.io/elliotechne/tfvisualizer
3. Tag with commit SHA, branch name, and 'latest'
4. Deploy to Kubernetes

### Method 2: Manual Build and Push

#### Step 1: Create GitHub Personal Access Token

1. Go to https://github.com/settings/tokens
2. Click **Generate new token** → **Generate new token (classic)**
3. Set scopes:
   - ✅ `write:packages` (push images)
   - ✅ `read:packages` (pull images)
   - ✅ `delete:packages` (optional, delete images)
4. Generate and save token: `ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

#### Step 2: Login to GHCR

```bash
# Set token as environment variable
export CR_PAT=ghp_your_personal_access_token

# Login to GHCR
echo $CR_PAT | docker login ghcr.io -u elliotechne --password-stdin
```

#### Step 3: Build and Push

```bash
# Build image
docker build -t ghcr.io/elliotechne/tfvisualizer:latest .

# Tag with version
docker tag ghcr.io/elliotechne/tfvisualizer:latest ghcr.io/elliotechne/tfvisualizer:v1.0.0

# Push images
docker push ghcr.io/elliotechne/tfvisualizer:latest
docker push ghcr.io/elliotechne/tfvisualizer:v1.0.0
```

---

## 🔒 Kubernetes Secret Configuration

### Create Docker Registry Secret

For pulling private images in Kubernetes:

```bash
# Using kubectl
kubectl create secret docker-registry docker-registry-credentials \
  --docker-server=ghcr.io \
  --docker-username=elliotechne \
  --docker-password=ghp_your_personal_access_token \
  --docker-email=your-email@example.com \
  --namespace=tfvisualizer

# Verify secret
kubectl get secret docker-registry-credentials -n tfvisualizer
```

### Or Add to Terraform

The secret is automatically created by Terraform in `kubernetes.tf`:

```hcl
resource "kubernetes_secret" "docker_registry" {
  metadata {
    name      = "docker-registry-credentials"
    namespace = kubernetes_namespace.tfvisualizer.metadata[0].name
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "ghcr.io" = {
          username = var.docker_registry_username
          password = var.docker_registry_password
          email    = var.docker_registry_email
          auth     = base64encode("${var.docker_registry_username}:${var.docker_registry_password}")
        }
      }
    })
  }
}
```

Set in `terraform.tfvars`:

```hcl
docker_registry          = "ghcr.io"
docker_image             = "ghcr.io/elliotechne/tfvisualizer"
docker_registry_username = "elliotechne"
docker_registry_password = "ghp_your_personal_access_token"
docker_registry_email    = "your-email@example.com"
```

---

## 📦 Image Tagging Strategy

### Automatic Tags (GitHub Actions)

The workflow creates multiple tags automatically:

```yaml
# Branch-based
ghcr.io/elliotechne/tfvisualizer:main
ghcr.io/elliotechne/tfvisualizer:develop

# Commit SHA
ghcr.io/elliotechne/tfvisualizer:main-abc1234

# Latest (main branch only)
ghcr.io/elliotechne/tfvisualizer:latest

# Semantic version (on git tags)
ghcr.io/elliotechne/tfvisualizer:1.0.0
ghcr.io/elliotechne/tfvisualizer:1.0
```

### Create Release Tag

```bash
# Tag release
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# GitHub Actions automatically builds:
# - ghcr.io/elliotechne/tfvisualizer:1.0.0
# - ghcr.io/elliotechne/tfvisualizer:1.0
# - ghcr.io/elliotechne/tfvisualizer:latest
```

---

## 🔍 Managing Images

### View Packages

1. Go to your GitHub profile
2. Click **Packages** tab
3. Find `tfvisualizer` package

Or directly: `https://github.com/elliotechne?tab=packages`

### Package Settings

Navigate to package page → **Package settings**:

- **Change visibility** (Public/Private)
- **Manage access** (Add teams/users)
- **Configure cleanup** (Delete old images)
- **View vulnerabilities**
- **See downloads/pulls**

### CLI Management

```bash
# List images
docker images ghcr.io/elliotechne/tfvisualizer

# Pull image
docker pull ghcr.io/elliotechne/tfvisualizer:latest

# Remove local image
docker rmi ghcr.io/elliotechne/tfvisualizer:latest

# Inspect image
docker inspect ghcr.io/elliotechne/tfvisualizer:latest
```

### Delete Images

Using GitHub CLI (`gh`):

```bash
# Install gh
brew install gh

# Authenticate
gh auth login

# Delete specific version
gh api \
  --method DELETE \
  -H "Accept: application/vnd.github+json" \
  /user/packages/container/tfvisualizer/versions/VERSION_ID

# List versions to find VERSION_ID
gh api \
  -H "Accept: application/vnd.github+json" \
  /user/packages/container/tfvisualizer/versions
```

---

## 🧹 Cleanup Policies

### Automatic Cleanup (Recommended)

Configure cleanup in package settings:

1. Go to package → **Package settings**
2. Scroll to **Danger Zone** → **Manage versions**
3. Enable automatic deletion:
   - Delete versions older than X days
   - Keep N most recent versions
   - Delete untagged versions

### Manual Cleanup Script

```bash
#!/bin/bash
# cleanup-old-images.sh

PACKAGE="tfvisualizer"
OWNER="elliotechne"
KEEP_VERSIONS=10

# Get all versions
VERSIONS=$(gh api \
  -H "Accept: application/vnd.github+json" \
  "/users/$OWNER/packages/container/$PACKAGE/versions" \
  --paginate \
  --jq '.[].id')

# Keep only latest N versions
echo "$VERSIONS" | tail -n +$((KEEP_VERSIONS + 1)) | while read VERSION_ID; do
  echo "Deleting version: $VERSION_ID"
  gh api \
    --method DELETE \
    -H "Accept: application/vnd.github+json" \
    "/users/$OWNER/packages/container/$PACKAGE/versions/$VERSION_ID"
done
```

---

## 🔐 Access Control

### Public Package

Make package publicly accessible:

1. Go to package → **Package settings**
2. Scroll to **Danger Zone** → **Change visibility**
3. Select **Public**

No authentication needed to pull:

```bash
docker pull ghcr.io/elliotechne/tfvisualizer:latest
```

### Private Package

For private packages, authentication is required:

```bash
# Login required
echo $CR_PAT | docker login ghcr.io -u elliotechne --password-stdin

# Pull image
docker pull ghcr.io/elliotechne/tfvisualizer:latest
```

### Team Access

Grant access to GitHub teams:

1. Go to package → **Package settings**
2. Under **Manage Actions access**, add teams
3. Set permissions (Read/Write/Admin)

---

## 📊 Storage and Billing

### Storage Limits

| Plan | Private Storage | Public Storage |
|------|----------------|----------------|
| Free | 500 MB | Unlimited |
| Pro | 2 GB | Unlimited |
| Team | 2 GB | Unlimited |
| Enterprise | 50 GB | Unlimited |

### Data Transfer

| Plan | Data Transfer/month |
|------|-------------------|
| Free | 1 GB |
| Pro | 10 GB |
| Team | 10 GB |
| Enterprise | 100 GB |

### Monitor Usage

View usage in GitHub settings:
- Go to **Settings** → **Billing and plans**
- Under **Storage for Actions and Packages**

---

## 🚨 Troubleshooting

### 403 Forbidden Error

```bash
Error response from daemon: pull access denied for ghcr.io/elliotechne/tfvisualizer
```

**Solution:**
1. Ensure you're logged in: `docker login ghcr.io`
2. Check token has `read:packages` scope
3. Verify package visibility (private requires auth)

### 401 Unauthorized

```bash
Error response from daemon: unauthorized: authentication required
```

**Solution:**
1. Login with correct credentials
2. Use personal access token (not password)
3. Check token hasn't expired

### Package Not Found

```bash
Error: Error response from daemon: manifest for ghcr.io/elliotechne/tfvisualizer:latest not found
```

**Solution:**
1. Verify image exists in GitHub packages
2. Check spelling of username/repository
3. Ensure tag exists (try `:main` instead of `:latest`)

### GitHub Actions Permission Denied

```bash
Error: denied: permission_denied: write_package
```

**Solution:**
1. Go to repo **Settings** → **Actions** → **General**
2. Set "Workflow permissions" to **Read and write**
3. Re-run workflow

### Kubernetes ImagePullBackOff

```bash
kubectl get pods -n tfvisualizer
# Status: ImagePullBackOff
```

**Solution:**
1. Check docker-registry-credentials secret exists
2. Verify credentials are correct
3. Ensure image tag exists in GHCR

```bash
# Debug
kubectl describe pod <pod-name> -n tfvisualizer
kubectl get secret docker-registry-credentials -n tfvisualizer
```

---

## 🔗 Integration Examples

### Docker Compose

```yaml
version: '3.8'
services:
  app:
    image: ghcr.io/elliotechne/tfvisualizer:latest
    ports:
      - "80:80"
```

### Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: tfvisualizer
        image: ghcr.io/elliotechne/tfvisualizer:latest
      imagePullSecrets:
      - name: docker-registry-credentials
```

### Docker Run

```bash
# Public image
docker run -p 80:80 ghcr.io/elliotechne/tfvisualizer:latest

# Private image
docker login ghcr.io
docker run -p 80:80 ghcr.io/elliotechne/tfvisualizer:latest
```

---

## 📚 Additional Resources

- [GHCR Documentation](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [GitHub Actions Docker Guide](https://docs.github.com/en/actions/publishing-packages/publishing-docker-images)
- [Personal Access Tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)
- [Package Permissions](https://docs.github.com/en/packages/learn-github-packages/configuring-a-packages-access-control-and-visibility)

---

**Container images now stored on ghcr.io**
