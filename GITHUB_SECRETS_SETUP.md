# GitHub Secrets Configuration Guide

Complete guide for setting up GitHub Secrets for Terraform CI/CD pipeline.

---

## 🔐 Required GitHub Secrets

All passwords and sensitive variables must be configured as GitHub repository secrets.

### Navigation

Go to: **GitHub Repository** → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

---

## 📋 Secret List

### 1. DigitalOcean Credentials

| Secret Name | Description | How to Get | Example |
|-------------|-------------|------------|---------|
| `DIGITALOCEAN_TOKEN` | DigitalOcean API token | [API Tokens](https://cloud.digitalocean.com/account/api/tokens) | `dop_v1_abc123...` |
| `DO_SPACES_ACCESS_KEY` | Spaces access key | [Spaces Keys](https://cloud.digitalocean.com/account/api/spaces) | `ABC123DEF456...` |
| `DO_SPACES_SECRET_KEY` | Spaces secret key | [Spaces Keys](https://cloud.digitalocean.com/account/api/spaces) | `xyz789abc123...` |

#### Instructions:
```bash
# 1. Create DigitalOcean API Token
# - Go to: https://cloud.digitalocean.com/account/api/tokens
# - Click "Generate New Token"
# - Name: "terraform-github-actions"
# - Scopes: Read & Write
# - Copy the token (starts with dop_v1_)

# 2. Create Spaces Access Keys
# - Go to: https://cloud.digitalocean.com/account/api/spaces
# - Click "Generate New Key"
# - Name: "terraform-state-backend"
# - Copy both access key and secret key
```

---

### 2. Database Passwords

| Secret Name | Description | Requirements | Example |
|-------------|-------------|--------------|---------|
| `POSTGRES_PASSWORD` | PostgreSQL password | Min 32 chars, alphanumeric + symbols | `Pg$ecure_P@ssw0rd_2024_XyZ` |
| `REDIS_PASSWORD` | Redis password | Min 32 chars, alphanumeric + symbols | `Red!s_Secur3_K3y_2024_AbC` |

#### Instructions:
```bash
# Generate secure passwords
openssl rand -base64 32

# Or use a password manager
# Requirements:
# - Minimum 32 characters
# - Mix of uppercase, lowercase, numbers, symbols
# - No spaces
# - Avoid special shell characters: ` $ " ' \
```

---

### 3. Application Secrets

| Secret Name | Description | Requirements | Example |
|-------------|-------------|--------------|---------|
| `APP_SECRET_KEY` | Flask secret key | Min 32 chars, random string | `flask_s3cr3t_k3y_2024_xyz...` |
| `JWT_SECRET` | JWT token secret | Min 32 chars, random string | `jwt_t0k3n_s3cr3t_2024_abc...` |

#### Instructions:
```bash
# Generate Flask secret key
python -c "import secrets; print(secrets.token_urlsafe(32))"

# Generate JWT secret
python -c "import secrets; print(secrets.token_hex(32))"

# Or use OpenSSL
openssl rand -hex 32
```

---

### 4. Stripe Configuration

| Secret Name | Description | How to Get | Example |
|-------------|-------------|------------|---------|
| `STRIPE_SECRET_KEY` | Stripe API secret key | [API Keys](https://dashboard.stripe.com/apikeys) | `sk_live_abc123...` or `sk_test_...` |
| `STRIPE_PUBLISHABLE_KEY` | Stripe publishable key | [API Keys](https://dashboard.stripe.com/apikeys) | `pk_live_xyz789...` or `pk_test_...` |
| `STRIPE_WEBHOOK_SECRET` | Webhook signing secret | [Webhooks](https://dashboard.stripe.com/webhooks) | `whsec_abc123...` |
| `STRIPE_PRICE_ID_PRO` | Price ID for Pro tier | [Products](https://dashboard.stripe.com/products) | `price_1ABC123...` |

#### Instructions:
```bash
# 1. Get API Keys
# - Go to: https://dashboard.stripe.com/apikeys
# - Copy "Secret key" (starts with sk_live_ or sk_test_)
# - Copy "Publishable key" (starts with pk_live_ or pk_test_)

# 2. Create Product & Price
# - Go to: https://dashboard.stripe.com/products
# - Create product: "TFVisualizer Pro"
# - Add price: $4.99/month recurring
# - Copy the price ID (starts with price_)

# 3. Create Webhook
# - Go to: https://dashboard.stripe.com/webhooks
# - Add endpoint: https://yourdomain.com/api/webhooks/stripe
# - Select events: customer.subscription.*, payment_intent.*
# - Copy "Signing secret" (starts with whsec_)
```

---

### 5. Docker Registry

| Secret Name | Description | Value | Example |
|-------------|-------------|-------|---------|
| `DOCKER_REGISTRY_EMAIL` | Email for GHCR | Your GitHub email | `user@example.com` |

**Note:** Username and password are automatically set:
- Username: `${{ github.actor }}` (automatic)
- Password: `${{ secrets.GITHUB_TOKEN }}` (automatic)

#### Instructions:
```bash
# Just add your email address
# This is used for Docker registry authentication metadata
```

---

## 🚀 Quick Setup Script

### Step 1: Prepare Values

Create a local file (DO NOT commit):

```bash
# secrets.env (add to .gitignore)
DIGITALOCEAN_TOKEN="dop_v1_your_token"
DO_SPACES_ACCESS_KEY="your_spaces_key"
DO_SPACES_SECRET_KEY="your_spaces_secret"
POSTGRES_PASSWORD="$(openssl rand -base64 32)"
REDIS_PASSWORD="$(openssl rand -base64 32)"
APP_SECRET_KEY="$(openssl rand -hex 32)"
JWT_SECRET="$(openssl rand -hex 32)"
STRIPE_SECRET_KEY="sk_live_your_key"
STRIPE_PUBLISHABLE_KEY="pk_live_your_key"
STRIPE_WEBHOOK_SECRET="whsec_your_secret"
STRIPE_PRICE_ID_PRO="price_your_id"
DOCKER_REGISTRY_EMAIL="your-email@example.com"
```

### Step 2: Add Secrets via GitHub CLI

```bash
# Install GitHub CLI
brew install gh  # macOS
# or: sudo apt install gh  # Ubuntu

# Authenticate
gh auth login

# Load secrets file
source secrets.env

# Add all secrets
gh secret set DIGITALOCEAN_TOKEN --body "$DIGITALOCEAN_TOKEN"
gh secret set DO_SPACES_ACCESS_KEY --body "$DO_SPACES_ACCESS_KEY"
gh secret set DO_SPACES_SECRET_KEY --body "$DO_SPACES_SECRET_KEY"
gh secret set POSTGRES_PASSWORD --body "$POSTGRES_PASSWORD"
gh secret set REDIS_PASSWORD --body "$REDIS_PASSWORD"
gh secret set APP_SECRET_KEY --body "$APP_SECRET_KEY"
gh secret set JWT_SECRET --body "$JWT_SECRET"
gh secret set STRIPE_SECRET_KEY --body "$STRIPE_SECRET_KEY"
gh secret set STRIPE_PUBLISHABLE_KEY --body "$STRIPE_PUBLISHABLE_KEY"
gh secret set STRIPE_WEBHOOK_SECRET --body "$STRIPE_WEBHOOK_SECRET"
gh secret set STRIPE_PRICE_ID_PRO --body "$STRIPE_PRICE_ID_PRO"
gh secret set DOCKER_REGISTRY_EMAIL --body "$DOCKER_REGISTRY_EMAIL"

# Clean up
rm secrets.env
unset DIGITALOCEAN_TOKEN DO_SPACES_ACCESS_KEY DO_SPACES_SECRET_KEY
unset POSTGRES_PASSWORD REDIS_PASSWORD APP_SECRET_KEY JWT_SECRET
unset STRIPE_SECRET_KEY STRIPE_PUBLISHABLE_KEY STRIPE_WEBHOOK_SECRET STRIPE_PRICE_ID_PRO
unset DOCKER_REGISTRY_EMAIL
```

### Step 3: Verify Secrets

```bash
# List all secrets
gh secret list

# Expected output:
# DIGITALOCEAN_TOKEN    Updated 2024-10-06
# DO_SPACES_ACCESS_KEY  Updated 2024-10-06
# DO_SPACES_SECRET_KEY  Updated 2024-10-06
# POSTGRES_PASSWORD     Updated 2024-10-06
# REDIS_PASSWORD        Updated 2024-10-06
# APP_SECRET_KEY        Updated 2024-10-06
# JWT_SECRET            Updated 2024-10-06
# STRIPE_SECRET_KEY     Updated 2024-10-06
# STRIPE_PUBLISHABLE_KEY Updated 2024-10-06
# STRIPE_WEBHOOK_SECRET Updated 2024-10-06
# STRIPE_PRICE_ID_PRO   Updated 2024-10-06
# DOCKER_REGISTRY_EMAIL Updated 2024-10-06
```

---

## 📝 Manual Setup (GitHub UI)

### For Each Secret:

1. Go to repository **Settings**
2. Click **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Enter name (e.g., `POSTGRES_PASSWORD`)
5. Paste value
6. Click **Add secret**
7. Repeat for all secrets

---

## 🔄 How Secrets Are Used

### In GitHub Actions Workflow

The workflow file (`.github/workflows/terraform.yml`) uses secrets via environment variables:

```yaml
env:
  # Terraform automatically reads TF_VAR_* environment variables
  TF_VAR_do_token: ${{ secrets.DIGITALOCEAN_TOKEN }}
  TF_VAR_postgres_password: ${{ secrets.POSTGRES_PASSWORD }}
  TF_VAR_redis_password: ${{ secrets.REDIS_PASSWORD }}
  TF_VAR_secret_key: ${{ secrets.APP_SECRET_KEY }}
  TF_VAR_jwt_secret: ${{ secrets.JWT_SECRET }}
  TF_VAR_stripe_secret_key: ${{ secrets.STRIPE_SECRET_KEY }}
  TF_VAR_stripe_publishable_key: ${{ secrets.STRIPE_PUBLISHABLE_KEY }}
  TF_VAR_stripe_webhook_secret: ${{ secrets.STRIPE_WEBHOOK_SECRET }}
  TF_VAR_stripe_price_id_pro: ${{ secrets.STRIPE_PRICE_ID_PRO }}
  TF_VAR_spaces_access_key: ${{ secrets.DO_SPACES_ACCESS_KEY }}
  TF_VAR_spaces_secret_key: ${{ secrets.DO_SPACES_SECRET_KEY }}
  TF_VAR_docker_registry_username: ${{ github.actor }}
  TF_VAR_docker_registry_password: ${{ secrets.GITHUB_TOKEN }}
  TF_VAR_docker_registry_email: ${{ secrets.DOCKER_REGISTRY_EMAIL }}
```

### Terraform Variable Mapping

| GitHub Secret | Terraform Variable | Terraform File |
|---------------|-------------------|----------------|
| `DIGITALOCEAN_TOKEN` | `do_token` | `variables.tf` |
| `POSTGRES_PASSWORD` | `postgres_password` | `variables.tf` |
| `REDIS_PASSWORD` | `redis_password` | `variables.tf` |
| `APP_SECRET_KEY` | `secret_key` | `variables.tf` |
| `JWT_SECRET` | `jwt_secret` | `variables.tf` |
| `STRIPE_SECRET_KEY` | `stripe_secret_key` | `variables.tf` |
| `STRIPE_PUBLISHABLE_KEY` | `stripe_publishable_key` | `variables.tf` |
| `STRIPE_WEBHOOK_SECRET` | `stripe_webhook_secret` | `variables.tf` |
| `STRIPE_PRICE_ID_PRO` | `stripe_price_id_pro` | `variables.tf` |
| `DO_SPACES_ACCESS_KEY` | `spaces_access_key` | `variables.tf` |
| `DO_SPACES_SECRET_KEY` | `spaces_secret_key` | `variables.tf` |
| `DOCKER_REGISTRY_EMAIL` | `docker_registry_email` | `variables.tf` |

---

## 🔒 Security Best Practices

### DO:
✅ Use strong, random passwords (32+ characters)
✅ Generate unique passwords for each service
✅ Rotate secrets regularly (every 90 days)
✅ Use GitHub CLI or UI to add secrets
✅ Enable branch protection for main
✅ Require pull request reviews

### DON'T:
❌ Commit secrets to Git
❌ Share secrets in plaintext
❌ Use weak or common passwords
❌ Reuse passwords across services
❌ Store secrets in code or comments
❌ Log secrets in GitHub Actions

---

## 🔍 Troubleshooting

### Secret Not Found Error

```
Error: Required secret POSTGRES_PASSWORD not found
```

**Solution:**
1. Verify secret name matches exactly (case-sensitive)
2. Check secret is added to correct repository
3. Verify workflow has access to secrets

### Invalid Secret Value

```
Error: Invalid value for variable postgres_password
```

**Solution:**
1. Ensure no trailing spaces or newlines
2. Check for special characters that need escaping
3. Regenerate secret if corrupted

### Workflow Can't Access Secrets

```
Error: Permission denied
```

**Solution:**
1. Check workflow permissions in repository settings
2. Verify Actions is enabled for repository
3. Ensure branch protection allows Actions

---

## 📊 Secret Rotation Schedule

| Secret Type | Rotation Period | Process |
|-------------|----------------|---------|
| Database Passwords | 90 days | Update in GitHub Secrets → Deploy |
| API Keys | 180 days | Regenerate in provider → Update secret |
| JWT/App Secrets | 180 days | Generate new → Update secret → Deploy |
| Stripe Keys | Annually | Rotate in Stripe dashboard → Update |

### Rotation Process:

```bash
# 1. Generate new value
NEW_PASSWORD=$(openssl rand -base64 32)

# 2. Update GitHub Secret
gh secret set POSTGRES_PASSWORD --body "$NEW_PASSWORD"

# 3. Trigger deployment
git commit --allow-empty -m "Rotate secrets"
git push origin main

# 4. Verify deployment
kubectl get pods -n tfvisualizer
```

---

## 📚 Additional Resources

- [GitHub Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [DigitalOcean API](https://docs.digitalocean.com/reference/api/)
- [Stripe API Keys](https://stripe.com/docs/keys)
- [Terraform Variables](https://www.terraform.io/docs/language/values/variables.html)

---

## ✅ Checklist

Before running CI/CD pipeline:

- [ ] All 12 GitHub Secrets are added
- [ ] Secrets tested with `gh secret list`
- [ ] DigitalOcean API token has read/write permissions
- [ ] Spaces bucket created for Terraform state
- [ ] Stripe webhook endpoint configured
- [ ] Docker registry email is valid
- [ ] Branch protection enabled on main
- [ ] Workflow permissions configured

---

**🔐 Keep secrets secure. Never commit to Git. Rotate regularly.**
