# Terraform S3 Backend Syntax Update

## Change Summary

Updated the DigitalOcean Spaces backend configuration to use the modern `endpoints` syntax instead of the deprecated `endpoint` syntax.

---

## What Changed

### Before (Deprecated)

```hcl
terraform {
  backend "s3" {
    endpoint = "nyc3.digitaloceanspaces.com"
    region   = "us-east-1"
    ...
  }
}
```

### After (Current)

```hcl
terraform {
  backend "s3" {
    endpoints = { s3 = "https://nyc3.digitaloceanspaces.com" }
    region    = "us-east-1"
    ...
  }
}
```

---

## Key Differences

| Aspect | Old Syntax | New Syntax |
|--------|-----------|------------|
| **Parameter** | `endpoint` (singular) | `endpoints` (plural) |
| **Format** | String: `"nyc3.digitaloceanspaces.com"` | Map: `{ s3 = "https://..." }` |
| **Protocol** | HTTP assumed | HTTPS explicit |
| **Support** | Deprecated | Current standard |

---

## Why This Change?

### 1. **Modern Terraform Standard**
Terraform 1.6+ uses the `endpoints` map syntax to support multiple AWS service endpoints separately (S3, DynamoDB, etc.).

### 2. **Explicit Protocol**
The new syntax requires `https://` prefix, making the secure connection explicit.

### 3. **Future-Proof**
The `endpoint` parameter is deprecated and may be removed in future Terraform versions.

### 4. **Better Service Separation**
Allows configuring different endpoints for different AWS services:
```hcl
endpoints = {
  s3       = "https://s3.custom.com"
  dynamodb = "https://dynamodb.custom.com"
}
```

---

## Files Updated

### 1. `terraform/backend.tf`
**Line 5:** Changed from `endpoint` to `endpoints`

```diff
terraform {
  backend "s3" {
-   endpoint = "nyc3.digitaloceanspaces.com"
+   endpoints = { s3 = "https://nyc3.digitaloceanspaces.com" }
    region   = "us-east-1"
    ...
  }
}
```

### 2. `INFRASTRUCTURE_AS_CODE.md`
**Line 183:** Updated documentation example

### 3. `TERRAFORM_PROVIDER_FIX.md`
**Line 64:** Updated provider fix documentation

---

## Testing

### Verify Configuration

```bash
cd terraform

# Test without backend initialization
terraform init -backend=false

# Expected: Success with no errors
```

### Full Backend Initialization

```bash
# Set credentials
export AWS_ACCESS_KEY_ID="your_do_spaces_access_key"
export AWS_SECRET_ACCESS_KEY="your_do_spaces_secret_key"

# Initialize with backend
terraform init

# Expected:
# - Initializing the backend...
# - Successfully configured the backend "s3"!
```

### Validate Endpoint

```bash
# The endpoint should now use HTTPS
terraform init 2>&1 | grep -i "https://nyc3"

# Or check the .terraform/terraform.tfstate file
cat .terraform/terraform.tfstate | grep endpoint
```

---

## Migration Guide

If you have an existing Terraform state with the old syntax:

### Option 1: Reconfigure Backend (Recommended)

```bash
cd terraform

# Reconfigure backend with new syntax
terraform init -reconfigure \
  -backend-config="access_key=$DO_SPACES_ACCESS_KEY" \
  -backend-config="secret_key=$DO_SPACES_SECRET_KEY"
```

### Option 2: Migrate Backend

```bash
# If switching between backends or configurations
terraform init -migrate-state \
  -backend-config="access_key=$DO_SPACES_ACCESS_KEY" \
  -backend-config="secret_key=$DO_SPACES_SECRET_KEY"
```

**Note:** `-reconfigure` is safer for syntax updates without changing the actual backend location.

---

## DigitalOcean Spaces Endpoints

### Available Regions

| Region | Endpoint |
|--------|----------|
| NYC3 | `https://nyc3.digitaloceanspaces.com` |
| AMS3 | `https://ams3.digitaloceanspaces.com` |
| SFO2 | `https://sfo2.digitaloceanspaces.com` |
| SFO3 | `https://sfo3.digitaloceanspaces.com` |
| SGP1 | `https://sgp1.digitaloceanspaces.com` |
| FRA1 | `https://fra1.digitaloceanspaces.com` |

### Choosing a Region

```hcl
# For NYC3 (current)
endpoints = { s3 = "https://nyc3.digitaloceanspaces.com" }

# For Amsterdam
endpoints = { s3 = "https://ams3.digitaloceanspaces.com" }

# For San Francisco
endpoints = { s3 = "https://sfo3.digitaloceanspaces.com" }
```

**Note:** Choose the region closest to your deployment for lower latency.

---

## Backend Configuration Reference

### Complete Configuration

```hcl
terraform {
  backend "s3" {
    # DigitalOcean Spaces endpoint
    endpoints = { s3 = "https://nyc3.digitaloceanspaces.com" }

    # Required but not used by Spaces
    region = "us-east-1"

    # State storage location
    bucket = "tfvisualizer-terraform-state"
    key    = "production/terraform.tfstate"

    # Skip AWS-specific validations (required for non-AWS S3-compatible backends)
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true  # Prevents "AWS account ID not found" error
  }

  required_version = ">= 1.6.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.34.0"
    }
  }
}
```

### Initialization Commands

```bash
# Method 1: Environment variables
export AWS_ACCESS_KEY_ID="your_do_spaces_access_key"
export AWS_SECRET_ACCESS_KEY="your_do_spaces_secret_key"
terraform init

# Method 2: Backend config flags
terraform init \
  -backend-config="access_key=your_do_spaces_access_key" \
  -backend-config="secret_key=your_do_spaces_secret_key"

# Method 3: Backend config file
# Create backend-config.tfvars:
# access_key = "your_do_spaces_access_key"
# secret_key = "your_do_spaces_secret_key"
terraform init -backend-config=backend-config.tfvars
```

---

## Troubleshooting

### Error: Invalid backend configuration

```
Error: Unsupported argument
The argument "endpoint" is not expected here.
```

**Solution:** You're using old syntax. Update to `endpoints = { s3 = "https://..." }`

### Error: Failed to get existing workspaces

```
Error: Failed to get existing workspaces: RequestError: send request failed
caused by: Get "http://nyc3.digitaloceanspaces.com": dial tcp: lookup nyc3.digitaloceanspaces.com
```

**Solution:** Missing `https://` protocol in endpoint. Use:
```hcl
endpoints = { s3 = "https://nyc3.digitaloceanspaces.com" }
```

### Error: AWS account ID not found

```
Error: AWS account ID not previously found and failed retrieving via all available methods
```

**Solution:** Add `skip_requesting_account_id = true` to backend configuration:
```hcl
backend "s3" {
  endpoints                   = { s3 = "https://nyc3.digitaloceanspaces.com" }
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_requesting_account_id  = true  # Add this line
}
```

**Why:** DigitalOcean Spaces doesn't have AWS account IDs. This flag prevents Terraform from trying to retrieve one.

### Error: Access Denied

```
Error: error configuring S3 Backend: error validating provider credentials:
AccessDenied: Access Denied
```

**Solution:**
1. Check Spaces access key and secret key are correct
2. Verify bucket name exists: `tfvisualizer-terraform-state`
3. Ensure Spaces key has read/write permissions

---

## GitHub Actions Integration

The GitHub Actions workflow automatically uses the correct syntax:

**File:** `.github/workflows/terraform.yml`

```yaml
- name: Terraform Init
  working-directory: ${{ env.TF_WORKING_DIR }}
  env:
    DIGITALOCEAN_TOKEN: ${{ secrets.DIGITALOCEAN_TOKEN }}
    DO_SPACES_ACCESS_KEY: ${{ secrets.DO_SPACES_ACCESS_KEY }}
    DO_SPACES_SECRET_KEY: ${{ secrets.DO_SPACES_SECRET_KEY }}
  run: |
    terraform init \
      -backend-config="access_key=$DO_SPACES_ACCESS_KEY" \
      -backend-config="secret_key=$DO_SPACES_SECRET_KEY"
```

**Note:** The workflow passes credentials via backend-config flags, which works with the new `endpoints` syntax.

---

## Benefits of New Syntax

### ✅ Advantages

1. **Standards Compliance**: Follows current Terraform best practices
2. **Future-Proof**: Won't be deprecated in future versions
3. **Explicit Security**: HTTPS protocol is clearly specified
4. **Better Debugging**: Clearer what endpoint is being used
5. **Service-Specific**: Can configure different endpoints per AWS service

### ⚠️ Considerations

1. **Backward Compatibility**: Old syntax still works but is deprecated
2. **Documentation**: Need to update all references
3. **Team Communication**: Inform team members of the change

---

## Related Documentation

- [Terraform S3 Backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [DigitalOcean Spaces](https://docs.digitalocean.com/products/spaces/)
- [INFRASTRUCTURE_AS_CODE.md](INFRASTRUCTURE_AS_CODE.md) - Complete infrastructure overview
- [TERRAFORM_PROVIDER_FIX.md](TERRAFORM_PROVIDER_FIX.md) - Provider configuration

---

## Checklist

- [x] Updated `terraform/backend.tf` with new `endpoints` syntax
- [x] Added `https://` protocol to endpoint URL
- [x] Updated documentation files (INFRASTRUCTURE_AS_CODE.md, TERRAFORM_PROVIDER_FIX.md)
- [x] Tested `terraform init -backend=false` successfully
- [ ] Test full backend initialization with Spaces credentials
- [ ] Update any team documentation or runbooks
- [ ] Inform team members of syntax change

---

**Backend configuration updated to modern Terraform syntax. ✅**
