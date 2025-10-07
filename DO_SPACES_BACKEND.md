# DigitalOcean Spaces as Terraform Backend

Quick reference for using DigitalOcean Spaces as a Terraform S3-compatible backend.

---

## Complete Configuration

### backend.tf

```hcl
terraform {
  backend "s3" {
    # DigitalOcean Spaces endpoint (S3-compatible)
    endpoints = { s3 = "https://nyc3.digitaloceanspaces.com" }

    # Required by Terraform but not used by Spaces
    region = "us-east-1"

    # State file location
    bucket = "tfvisualizer-terraform-state"
    key    = "production/terraform.tfstate"

    # Skip AWS-specific checks (REQUIRED for DigitalOcean Spaces)
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
  }

  required_version = ">= 1.6.0"
}
```

---

## Required Skip Flags

All four skip flags are **required** for DigitalOcean Spaces:

| Flag | Purpose | What it prevents |
|------|---------|------------------|
| `skip_credentials_validation` | Skip AWS credential validation | "InvalidClientTokenId" errors |
| `skip_metadata_api_check` | Skip AWS metadata API calls | EC2 metadata endpoint errors |
| `skip_region_validation` | Skip AWS region validation | "InvalidRegion" errors |
| `skip_requesting_account_id` | Skip AWS account ID retrieval | "AWS account ID not found" errors |

**Without these flags**, Terraform will attempt to contact AWS services even though you're using DigitalOcean Spaces.

---

## Initialization

### Option 1: Environment Variables (Recommended)

```bash
export AWS_ACCESS_KEY_ID="your_do_spaces_access_key"
export AWS_SECRET_ACCESS_KEY="your_do_spaces_secret_key"

cd terraform
terraform init
```

### Option 2: Backend Config Flags

```bash
cd terraform
terraform init \
  -backend-config="access_key=your_do_spaces_access_key" \
  -backend-config="secret_key=your_do_spaces_secret_key"
```

### Option 3: Backend Config File

Create `backend-config.tfvars`:
```hcl
access_key = "your_do_spaces_access_key"
secret_key = "your_do_spaces_secret_key"
```

Then initialize:
```bash
terraform init -backend-config=backend-config.tfvars
```

**Security Note:** Never commit `backend-config.tfvars` to Git. Add to `.gitignore`.

---

## Creating the Spaces Bucket

Before running `terraform init`, create the Spaces bucket:

### Via DigitalOcean CLI (doctl)

```bash
# Install doctl
brew install doctl  # macOS
# or: snap install doctl  # Linux

# Authenticate
doctl auth init

# Create Spaces bucket
doctl compute space create tfvisualizer-terraform-state \
  --region nyc3

# Verify
doctl compute space list
```

### Via Web UI

1. Go to https://cloud.digitalocean.com/spaces
2. Click **Create a Space**
3. Choose region: **New York 3 (nyc3)**
4. Name: `tfvisualizer-terraform-state`
5. Enable CDN: **No** (not needed for Terraform state)
6. File Listing: **Private** (important for security)
7. Click **Create Space**

---

## Getting Spaces Access Keys

### Via Web UI

1. Go to https://cloud.digitalocean.com/account/api/spaces
2. Click **Generate New Key**
3. Name: `terraform-state-backend`
4. Click **Generate Key**
5. **Copy both keys immediately** (secret key shown only once)
   - Access Key: Starts with uppercase letters
   - Secret Key: Long alphanumeric string

### Via doctl

```bash
# List existing keys
doctl compute spaces-access list

# Keys can only be created via web UI
```

---

## Available Regions

| Region Code | Location | Endpoint |
|-------------|----------|----------|
| `nyc3` | New York 3 | `https://nyc3.digitaloceanspaces.com` |
| `ams3` | Amsterdam 3 | `https://ams3.digitaloceanspaces.com` |
| `sfo2` | San Francisco 2 | `https://sfo2.digitaloceanspaces.com` |
| `sfo3` | San Francisco 3 | `https://sfo3.digitaloceanspaces.com` |
| `sgp1` | Singapore 1 | `https://sgp1.digitaloceanspaces.com` |
| `fra1` | Frankfurt 1 | `https://fra1.digitaloceanspaces.com` |

**Current Setup:** NYC3 (closest to most US deployments)

---

## State File Location

State file path in Spaces bucket:
```
s3://tfvisualizer-terraform-state/production/terraform.tfstate
```

**Structure:**
- Bucket: `tfvisualizer-terraform-state`
- Key (path): `production/terraform.tfstate`

**For multiple environments:**
```hcl
# Production
key = "production/terraform.tfstate"

# Staging
key = "staging/terraform.tfstate"

# Development
key = "development/terraform.tfstate"
```

---

## Common Errors and Solutions

### Error: AWS account ID not found

```
Error: AWS account ID not previously found and failed retrieving via all available methods
```

**Solution:** Add `skip_requesting_account_id = true`

### Error: No valid credential sources found

```
Error: No valid credential sources found for AWS Provider
```

**Solution:**
1. Set environment variables: `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
2. Or use `-backend-config` flags during `terraform init`

### Error: Bucket does not exist

```
Error: Failed to get existing workspaces: NoSuchBucket: The specified bucket does not exist
```

**Solution:**
1. Create the bucket in DigitalOcean Spaces
2. Verify bucket name matches backend configuration
3. Ensure you're using the correct region endpoint

### Error: Access Denied

```
Error: AccessDenied: Access Denied
```

**Solution:**
1. Verify Spaces access key and secret key are correct
2. Check key has read/write permissions
3. Ensure bucket file listing is set to "Private" (not "Public")

### Error: Connection refused

```
Error: connection refused
```

**Solution:**
1. Check endpoint includes `https://` protocol
2. Verify internet connectivity
3. Check firewall/proxy settings

---

## State Operations

### View Current State

```bash
terraform show
```

### List State Resources

```bash
terraform state list
```

### Pull State (Backup)

```bash
terraform state pull > terraform.tfstate.backup
```

### Push State (Restore)

```bash
terraform state push terraform.tfstate.backup
```

### Remove Resource from State

```bash
terraform state rm <resource_address>
```

---

## State Locking

**Important:** DigitalOcean Spaces does **NOT** support state locking natively.

### Implications

- Multiple `terraform apply` commands can run simultaneously
- Risk of state corruption if team members run Terraform concurrently
- No automatic conflict prevention

### Solutions

**Option 1: DynamoDB for Locking (Recommended for Teams)**

```hcl
terraform {
  backend "s3" {
    endpoints = { s3 = "https://nyc3.digitaloceanspaces.com" }
    bucket    = "tfvisualizer-terraform-state"
    key       = "production/terraform.tfstate"

    # Use AWS DynamoDB for locking
    dynamodb_table = "terraform-state-lock"
    region         = "us-east-1"

    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
  }
}
```

**Option 2: Terraform Cloud (Free for Small Teams)**

Use Terraform Cloud's remote backend instead of S3.

**Option 3: Process-Based Locking (Simple)**

Use GitHub Actions or CI/CD pipelines to ensure only one Terraform process runs at a time.

---

## Security Best Practices

### ✅ DO:

1. **Use environment variables** for credentials (not committed to Git)
2. **Rotate keys** every 90 days
3. **Use different keys** for CI/CD vs local development
4. **Set bucket to Private** file listing
5. **Enable versioning** on Spaces bucket (via web UI)
6. **Backup state files** regularly
7. **Use workspace separation** for different environments

### ❌ DON'T:

1. **Commit credentials** to Git
2. **Share keys** via plaintext (email, Slack, etc.)
3. **Use same key** for multiple projects
4. **Make bucket public**
5. **Disable versioning** (protects against accidental deletion)
6. **Edit state files** manually
7. **Run terraform apply** concurrently without locking

---

## GitHub Actions Integration

**File:** `.github/workflows/terraform.yml`

```yaml
env:
  # Terraform uses AWS_* env vars for S3 backend
  AWS_ACCESS_KEY_ID: ${{ secrets.DO_SPACES_ACCESS_KEY }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.DO_SPACES_SECRET_KEY }}

jobs:
  terraform:
    steps:
      - name: Terraform Init
        working-directory: ./terraform
        run: terraform init

      - name: Terraform Plan
        working-directory: ./terraform
        run: terraform plan

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main'
        working-directory: ./terraform
        run: terraform apply -auto-approve
```

**Required GitHub Secrets:**
- `DO_SPACES_ACCESS_KEY` - Your Spaces access key
- `DO_SPACES_SECRET_KEY` - Your Spaces secret key

---

## Cost

**DigitalOcean Spaces Pricing:**
- Storage: $5/month for 250GB
- Bandwidth: $0.01/GB outbound (after 1TB free)

**Typical Terraform state size:**
- Small project: < 1MB
- Medium project: 1-10MB
- Large project: 10-100MB

**Estimated cost for Terraform state only:** ~$5/month (minimum)

**Note:** You're already paying for Spaces, so using it for Terraform state is free additional usage.

---

## Monitoring State Access

### View Spaces Access Logs

DigitalOcean Spaces doesn't provide built-in access logs, but you can:

1. **Monitor via doctl:**
```bash
doctl compute space list-objects tfvisualizer-terraform-state
```

2. **Check state file timestamp:**
```bash
# Pull state and check last modified
terraform state pull | jq '.serial, .terraform_version, .lineage'
```

3. **Use Terraform Cloud** for detailed audit logs (migration required)

---

## Migration from Other Backends

### From Local State

```bash
# 1. Backup current state
cp terraform.tfstate terraform.tfstate.backup

# 2. Update backend.tf with S3 configuration

# 3. Initialize and migrate
terraform init -migrate-state

# 4. Verify
terraform state list
```

### From Another S3 Bucket

```bash
# Update backend.tf with new bucket/endpoint

terraform init -reconfigure -migrate-state
```

### To Terraform Cloud

```hcl
terraform {
  cloud {
    organization = "your-org"
    workspaces {
      name = "tfvisualizer-production"
    }
  }
}
```

```bash
terraform init -migrate-state
```

---

## Related Documentation

- [BACKEND_SYNTAX_UPDATE.md](BACKEND_SYNTAX_UPDATE.md) - Recent syntax changes
- [INFRASTRUCTURE_AS_CODE.md](INFRASTRUCTURE_AS_CODE.md) - Complete infrastructure
- [TERRAFORM_PROVIDER_FIX.md](TERRAFORM_PROVIDER_FIX.md) - Provider configuration
- [DigitalOcean Spaces Docs](https://docs.digitalocean.com/products/spaces/)
- [Terraform S3 Backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3)

---

**DigitalOcean Spaces is fully configured as your Terraform backend. ✅**
