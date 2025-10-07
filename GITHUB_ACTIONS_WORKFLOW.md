# GitHub Actions CI/CD Workflow

Complete guide for the Terraform CI/CD pipeline with Docker build integration.

---

## Overview

The workflow combines Docker image building with Terraform infrastructure deployment in a single automated pipeline.

**File:** `.github/workflows/terraform.yml`

---

## Workflow Jobs

```
┌─────────────────────┐
│  build-and-push     │  Build Docker image → Push to GHCR
└──────────┬──────────┘
           ↓
┌─────────────────────┐
│ terraform-validate  │  Format check → Init → Validate
└──────────┬──────────┘
           ↓
┌─────────────────────┐
│  terraform-plan     │  Plan changes → Upload artifact
└──────────┬──────────┘
           ↓
┌─────────────────────┐
│  terraform-apply    │  Apply plan → Deploy to K8s (main branch only)
└─────────────────────┘

┌─────────────────────┐
│ terraform-destroy   │  Manual workflow_dispatch only
└─────────────────────┘
```

---

## Jobs Breakdown

### 1. build-and-push

**Purpose:** Build and push Docker image to GitHub Container Registry (ghcr.io)

**Triggers:**
- Push to `main` or `develop`
- Pull requests
- Manual workflow dispatch

**Steps:**
1. Checkout code
2. Set up Docker Buildx (multi-platform builds)
3. Login to GHCR
4. Extract metadata (tags, labels)
5. Build and push image
6. Output image digest

**Image Tags Generated:**
- `ghcr.io/elliotechne/tfvisualizer:main` (on main branch)
- `ghcr.io/elliotechne/tfvisualizer:develop` (on develop branch)
- `ghcr.io/elliotechne/tfvisualizer:pr-123` (on PRs)
- `ghcr.io/elliotechne/tfvisualizer:main-a1b2c3d` (commit SHA)
- `ghcr.io/elliotechne/tfvisualizer:latest` (main branch only)

**Outputs:**
- `image-tag`: Full image tags
- `image-version`: Version tag

---

### 2. terraform-validate

**Purpose:** Validate Terraform configuration syntax and formatting

**Dependencies:** Requires `build-and-push` to complete

**Steps:**
1. Checkout code
2. Setup Terraform 1.6.0
3. Check formatting (`terraform fmt -check`)
4. Initialize without backend (`terraform init -backend=false`)
5. Validate configuration

**Note:** Uses `-backend=false` to skip backend initialization for faster validation.

---

### 3. terraform-plan

**Purpose:** Generate and preview infrastructure changes

**Dependencies:** Requires `terraform-validate` to pass

**Triggers:** Push or Pull Request events

**Steps:**
1. Checkout code
2. Setup Terraform
3. Initialize with backend (`terraform init`)
4. Generate plan (`terraform plan -out=tfplan`)
5. Upload plan as artifact
6. Comment PR with plan output (PRs only)

**Backend Initialization:**
Uses environment variables:
- `AWS_ACCESS_KEY_ID` → `DO_SPACES_ACCESS_KEY`
- `AWS_SECRET_ACCESS_KEY` → `DO_SPACES_SECRET_KEY`

---

### 4. terraform-apply

**Purpose:** Apply infrastructure changes and deploy to Kubernetes

**Dependencies:** Requires both `build-and-push` and `terraform-plan`

**Triggers:** Push to `main` branch only

**Environment:** `production` (requires approval if configured)

**Steps:**
1. Checkout code
2. Setup Terraform
3. Initialize with backend
4. Download plan artifact
5. Apply plan (`terraform apply -auto-approve tfplan`)
6. Export outputs to JSON
7. Upload outputs as artifact
8. Get Kubernetes kubeconfig
9. Update Kubernetes deployment with new image

**Kubernetes Deployment:**
```bash
IMAGE_TAG="ghcr.io/elliotechne/tfvisualizer:main-a1b2c3d"
kubectl set image deployment/tfvisualizer-app tfvisualizer=$IMAGE_TAG -n tfvisualizer
kubectl rollout status deployment/tfvisualizer-app -n tfvisualizer --timeout=5m
```

---

### 5. terraform-destroy

**Purpose:** Destroy all Terraform-managed infrastructure

**Triggers:** Manual `workflow_dispatch` only

**Environment:** `destroy` (requires approval)

**Steps:**
1. Checkout code
2. Setup Terraform
3. Initialize with backend
4. Destroy all resources (`terraform destroy -auto-approve`)

**⚠️ WARNING:** This destroys the entire infrastructure including databases. Use with extreme caution.

---

## Environment Variables

### Global Environment

Set at workflow level (available to all jobs):

```yaml
env:
  TF_VERSION: '1.6.0'
  TF_WORKING_DIR: './terraform'
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}
```

### Terraform Variables

All `TF_VAR_*` variables are passed to Terraform:

| Environment Variable | Terraform Variable | GitHub Secret |
|---------------------|-------------------|---------------|
| `TF_VAR_do_token` | `var.do_token` | `DIGITALOCEAN_TOKEN` |
| `TF_VAR_postgres_password` | `var.postgres_password` | `POSTGRES_PASSWORD` |
| `TF_VAR_redis_password` | `var.redis_password` | `REDIS_PASSWORD` |
| `TF_VAR_secret_key` | `var.secret_key` | `APP_SECRET_KEY` |
| `TF_VAR_jwt_secret` | `var.jwt_secret` | `JWT_SECRET` |
| `TF_VAR_stripe_secret_key` | `var.stripe_secret_key` | `STRIPE_SECRET_KEY` |
| `TF_VAR_stripe_publishable_key` | `var.stripe_publishable_key` | `STRIPE_PUBLISHABLE_KEY` |
| `TF_VAR_stripe_webhook_secret` | `var.stripe_webhook_secret` | `STRIPE_WEBHOOK_SECRET` |
| `TF_VAR_stripe_price_id_pro` | `var.stripe_price_id_pro` | `STRIPE_PRICE_ID_PRO` |
| `TF_VAR_spaces_access_key` | `var.spaces_access_key` | `DO_SPACES_ACCESS_KEY` |
| `TF_VAR_spaces_secret_key` | `var.spaces_secret_key` | `DO_SPACES_SECRET_KEY` |
| `TF_VAR_docker_registry_username` | `var.docker_registry_username` | `github.actor` |
| `TF_VAR_docker_registry_password` | `var.docker_registry_password` | `GITHUB_TOKEN` |
| `TF_VAR_docker_registry_email` | `var.docker_registry_email` | `DOCKER_REGISTRY_EMAIL` |

### Backend Credentials

```yaml
AWS_ACCESS_KEY_ID: ${{ secrets.DO_SPACES_ACCESS_KEY }}
AWS_SECRET_ACCESS_KEY: ${{ secrets.DO_SPACES_SECRET_KEY }}
```

**Note:** DigitalOcean Spaces uses AWS S3-compatible API, so `AWS_*` env vars are used for backend authentication.

---

## Required GitHub Secrets

### DigitalOcean Credentials (3)

| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `DIGITALOCEAN_TOKEN` | DigitalOcean API token | [API Tokens](https://cloud.digitalocean.com/account/api/tokens) |
| `DO_SPACES_ACCESS_KEY` | Spaces access key | [Spaces Keys](https://cloud.digitalocean.com/account/api/spaces) |
| `DO_SPACES_SECRET_KEY` | Spaces secret key | [Spaces Keys](https://cloud.digitalocean.com/account/api/spaces) |

### Database Passwords (2)

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `POSTGRES_PASSWORD` | PostgreSQL password | 32+ char random string |
| `REDIS_PASSWORD` | Redis password | 32+ char random string |

### Application Secrets (2)

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `APP_SECRET_KEY` | Flask secret key | 32+ char random string |
| `JWT_SECRET` | JWT token secret | 32+ char random string |

### Stripe Configuration (4)

| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `STRIPE_SECRET_KEY` | Stripe API secret | [API Keys](https://dashboard.stripe.com/apikeys) |
| `STRIPE_PUBLISHABLE_KEY` | Stripe publishable key | [API Keys](https://dashboard.stripe.com/apikeys) |
| `STRIPE_WEBHOOK_SECRET` | Webhook signing secret | [Webhooks](https://dashboard.stripe.com/webhooks) |
| `STRIPE_PRICE_ID_PRO` | Price ID for Pro tier | [Products](https://dashboard.stripe.com/products) |

### Docker Registry (1)

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `DOCKER_REGISTRY_EMAIL` | Email for GHCR | `user@example.com` |

**Note:** `GITHUB_TOKEN` is automatically provided by GitHub Actions.

**Total:** 12 required secrets

---

## Workflow Triggers

### Push Events

```yaml
on:
  push:
    branches:
      - main
      - develop
    paths:
      - 'terraform/**'
      - 'app/**'
      - 'templates/**'
      - 'static/**'
      - 'requirements.txt'
      - 'Dockerfile'
      - '.github/workflows/terraform.yml'
```

**Triggers when:**
- Code is pushed to `main` or `develop` branch
- Changes affect Terraform configs, app code, or Docker build

**Skips when:**
- Only documentation changes (`.md` files)
- Changes to other workflows
- Changes outside specified paths

### Pull Request Events

```yaml
on:
  pull_request:
    branches:
      - main
      - develop
    paths:
      - 'terraform/**'
      - 'app/**'
      - 'Dockerfile'
```

**Triggers when:**
- PR is opened, updated, or synchronized
- Target branch is `main` or `develop`
- Changes affect specified paths

**What runs:**
- Docker build (but doesn't push)
- Terraform validate
- Terraform plan (posts comment to PR)
- **Terraform apply does NOT run**

### Manual Dispatch

```yaml
on:
  workflow_dispatch:
```

**Allows:**
- Manual workflow execution from Actions tab
- Can run on any branch
- All jobs run except `terraform-destroy` (requires separate manual trigger)

---

## Deployment Flow

### Development Branch (`develop`)

```
Push to develop
    ↓
Build image → ghcr.io/elliotechne/tfvisualizer:develop
    ↓
Validate Terraform
    ↓
Plan changes
    ↓
❌ STOP (no apply on develop)
```

### Production Branch (`main`)

```
Push to main
    ↓
Build image → ghcr.io/elliotechne/tfvisualizer:main, latest
    ↓
Validate Terraform
    ↓
Plan changes
    ↓
Apply changes ✅
    ↓
Update Kubernetes deployment
    ↓
Rollout new version
```

### Pull Request

```
Open/Update PR
    ↓
Build image (test only, not pushed)
    ↓
Validate Terraform
    ↓
Plan changes
    ↓
Comment PR with plan output
    ↓
❌ STOP (no apply on PRs)
```

---

## Artifacts

### Terraform Plan

**Name:** `terraform-plan`
**Path:** `terraform/tfplan`
**Retention:** 5 days
**Action:** `actions/upload-artifact@v4`
**Used by:** `terraform-apply` job

**Purpose:** Store the plan output to ensure the exact plan is applied.

### Terraform Outputs

**Name:** `terraform-outputs`
**Path:** `terraform/terraform-outputs.json`
**Retention:** 30 days
**Action:** `actions/upload-artifact@v4`

**Purpose:** Store infrastructure outputs (endpoints, IPs, etc.) for debugging and reference.

**Example output:**
```json
{
  "cluster_endpoint": {
    "value": "https://abc123-k8s.nyc3.digitaloceanspaces.com"
  },
  "load_balancer_ip": {
    "value": "165.227.123.45"
  }
}
```

---

## Docker Image Tagging Strategy

### Tag Types

| Tag Type | Example | When Created |
|----------|---------|--------------|
| Branch | `main`, `develop` | Every push to branch |
| PR | `pr-123` | Pull requests |
| SHA | `main-a1b2c3d` | Every commit |
| Latest | `latest` | Push to main only |
| Semver | `v1.0.0`, `1.0`, `1` | Git tags (if used) |

### Tag Priority

When deploying to Kubernetes, tags are used in this order:

1. **SHA-based tag** (most specific): `main-a1b2c3d`
2. **Branch tag**: `main`
3. **Latest tag**: `latest`

**Current deployment uses:** SHA-based tag for reproducibility.

---

## Kubernetes Deployment

### Update Strategy

```bash
# Extract Git commit SHA
SHORT_SHA=$(git rev-parse --short HEAD)

# Build image tag
IMAGE_TAG="ghcr.io/elliotechne/tfvisualizer:main-${SHORT_SHA}"

# Update deployment
kubectl set image deployment/tfvisualizer-app \
  tfvisualizer=$IMAGE_TAG \
  -n tfvisualizer

# Wait for rollout to complete
kubectl rollout status deployment/tfvisualizer-app \
  -n tfvisualizer \
  --timeout=5m
```

### Rollback

If deployment fails, rollback to previous version:

```bash
kubectl rollout undo deployment/tfvisualizer-app -n tfvisualizer
```

Or from GitHub Actions, manually trigger with a specific image tag.

---

## Monitoring Workflow

### View Workflow Runs

1. Go to repository on GitHub
2. Click **Actions** tab
3. Click **Terraform CI/CD with Docker Build**
4. View run history and logs

### View Artifacts

1. Go to completed workflow run
2. Scroll to **Artifacts** section
3. Download `terraform-plan` or `terraform-outputs`

### Check Deployment Status

```bash
# View deployment status
kubectl get deployment tfvisualizer-app -n tfvisualizer

# View pods
kubectl get pods -n tfvisualizer

# View recent events
kubectl get events -n tfvisualizer --sort-by='.lastTimestamp'

# Check rollout status
kubectl rollout status deployment/tfvisualizer-app -n tfvisualizer
```

---

## Troubleshooting

### Issue: Workflow fails on Terraform init

**Error:**
```
Error: Failed to get existing workspaces
```

**Solution:**
1. Check `DO_SPACES_ACCESS_KEY` and `DO_SPACES_SECRET_KEY` are set correctly
2. Verify Spaces bucket exists: `tfvisualizer-terraform-state`
3. Check backend configuration in `terraform/backend.tf`

### Issue: Docker build fails

**Error:**
```
Error: buildx failed with: ERROR: failed to solve
```

**Solution:**
1. Check Dockerfile syntax
2. Verify all required files exist (requirements.txt, app/, templates/)
3. Check build logs for specific error

### Issue: Terraform apply times out

**Error:**
```
Error: context deadline exceeded
```

**Solution:**
1. Check DigitalOcean API token is valid
2. Verify no rate limits on DigitalOcean API
3. Review Terraform plan for large resource changes
4. Increase timeout if needed (workflow level)

### Issue: Kubernetes deployment fails

**Error:**
```
Error: context not available
```

**Solution:**
1. Verify kubeconfig is generated by Terraform output
2. Check Kubernetes cluster is accessible
3. Verify namespace `tfvisualizer` exists
4. Check deployment name matches: `tfvisualizer-app`

### Issue: Plan artifact not found

**Error:**
```
Error: Unable to find any artifacts for the associated workflow
```

**Solution:**
1. Ensure `terraform-plan` job completed successfully
2. Check artifact retention hasn't expired (5 days)
3. Verify artifact upload step didn't fail

---

## Security Considerations

### ✅ Best Practices

1. **Secrets Management:**
   - All sensitive values stored as GitHub Secrets
   - Never commit secrets to repository
   - Rotate secrets every 90 days

2. **Branch Protection:**
   - Require PR reviews for main branch
   - Require status checks to pass
   - Require up-to-date branches

3. **Environment Protection:**
   - Production environment requires approval
   - Destroy environment requires approval
   - Limit who can approve deployments

4. **Least Privilege:**
   - GitHub Actions token has minimal permissions
   - DigitalOcean token scoped to project
   - Kubernetes RBAC configured appropriately

### ⚠️ Security Notes

1. **Terraform State:**
   - Stored in DigitalOcean Spaces (encrypted at rest)
   - Access controlled by Spaces keys
   - No state locking (consider using Terraform Cloud)

2. **Docker Images:**
   - Images scanned for vulnerabilities (Trivy in docker-build.yml)
   - Published to GHCR (private by default)
   - Multi-platform builds for compatibility

3. **Workflow Permissions:**
   - `contents: read` - Read repository contents
   - `packages: write` - Push to GHCR

---

## Related Files

| File | Purpose |
|------|---------|
| `.github/workflows/terraform.yml` | Main CI/CD workflow |
| `.github/workflows/docker-build.yml` | Standalone Docker build |
| `terraform/backend.tf` | Terraform backend config |
| `terraform/variables.tf` | Terraform variables |
| `Dockerfile` | Application container definition |
| `GITHUB_SECRETS_SETUP.md` | GitHub Secrets setup guide |

---

## Next Steps

1. **Configure GitHub Secrets** (see GITHUB_SECRETS_SETUP.md)
2. **Create Spaces bucket** for Terraform state
3. **Push to develop branch** to test workflow
4. **Create PR** to test PR workflow
5. **Merge to main** to deploy to production

---

**Complete CI/CD pipeline with Docker build and Terraform deployment. ✅**
