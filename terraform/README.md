# Terraform Infrastructure for TFVisualizer

Complete DigitalOcean infrastructure as code for TFVisualizer application.

---

## 🏗️ Infrastructure Components

### Compute
- **Droplet**: Docker-enabled Ubuntu 20.04 droplet for application hosting
- **Load Balancer**: SSL-terminated load balancer with health checks
- **VPC**: Private network for secure communication

### Database
- **PostgreSQL 15**: Managed database cluster for application data
- **Redis 7**: Managed Redis cluster for caching and sessions

### Storage
- **Spaces**: S3-compatible object storage for file uploads

### Networking
- **Domain**: DNS management for tfvisualizer.com
- **SSL Certificate**: Let's Encrypt certificate for HTTPS

### Monitoring
- **CPU Alerts**: Notifications when CPU > 80%
- **Memory Alerts**: Notifications when memory > 90%

---

## 📋 Prerequisites

1. **DigitalOcean Account**
   - Create account at https://cloud.digitalocean.com

2. **DigitalOcean API Token**
   ```bash
   # Create at: https://cloud.digitalocean.com/account/api/tokens
   export DIGITALOCEAN_TOKEN="dop_v1_your_token_here"
   ```

3. **DigitalOcean Spaces Credentials**
   ```bash
   # Create at: https://cloud.digitalocean.com/account/api/spaces
   export DO_SPACES_ACCESS_KEY="your_spaces_access_key"
   export DO_SPACES_SECRET_KEY="your_spaces_secret_key"
   ```

4. **Terraform CLI**
   ```bash
   # Install Terraform 1.6.0+
   brew install terraform  # macOS
   # OR
   wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
   ```

5. **Create Spaces Bucket for State**
   ```bash
   # Create bucket manually or with doctl
   doctl spaces create tfvisualizer-terraform-state --region nyc3
   ```

---

## 🚀 Quick Start

### 1. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
nano terraform.tfvars
```

Required variables:
```hcl
do_token    = "dop_v1_your_token"
domain_name = "tfvisualizer.com"
alert_email = "your-email@example.com"
```

### 2. Initialize Terraform

```bash
cd terraform

# Initialize with DigitalOcean Spaces backend
terraform init \
  -backend-config="access_key=$DO_SPACES_ACCESS_KEY" \
  -backend-config="secret_key=$DO_SPACES_SECRET_KEY"
```

### 3. Plan Infrastructure

```bash
terraform plan -out=tfplan
```

### 4. Apply Changes

```bash
terraform apply tfplan
```

### 5. Get Outputs

```bash
# View all outputs
terraform output

# View specific output
terraform output database_uri

# Export outputs to JSON
terraform output -json > outputs.json
```

---

## 🔧 Configuration

### Environment Variables

For CI/CD or local development:

```bash
# Required
export DIGITALOCEAN_TOKEN="dop_v1_your_token"
export DO_SPACES_ACCESS_KEY="your_access_key"
export DO_SPACES_SECRET_KEY="your_secret_key"

# Optional
export TF_VAR_environment="production"
export TF_VAR_region="nyc3"
```

### Backend Configuration

State is stored in DigitalOcean Spaces (S3-compatible):

```hcl
backend "s3" {
  endpoint = "nyc3.digitaloceanspaces.com"
  region   = "us-east-1"
  bucket   = "tfvisualizer-terraform-state"
  key      = "production/terraform.tfstate"
}
```

### Workspace Management

```bash
# List workspaces
terraform workspace list

# Create staging workspace
terraform workspace new staging

# Switch workspace
terraform workspace select production
```

---

## 📊 Outputs

| Output | Description | Sensitive |
|--------|-------------|-----------|
| `app_droplet_ip` | Public IP of application server | No |
| `loadbalancer_ip` | Load balancer IP address | No |
| `database_uri` | PostgreSQL connection string | Yes |
| `database_host` | PostgreSQL hostname | Yes |
| `database_password` | PostgreSQL password | Yes |
| `redis_uri` | Redis connection string | Yes |
| `redis_host` | Redis hostname | Yes |
| `spaces_bucket_name` | Spaces bucket name | No |
| `domain_name` | Application domain | No |

### Accessing Sensitive Outputs

```bash
# View sensitive output
terraform output database_uri

# Save to environment file
terraform output -json | jq -r '.database_uri.value' > .env.database_uri
```

---

## 🔐 GitHub Actions Setup

### 1. Add Repository Secrets

Go to GitHub repository → Settings → Secrets and variables → Actions

Add the following secrets:

```
DIGITALOCEAN_TOKEN       = dop_v1_your_token
DO_SPACES_ACCESS_KEY     = your_spaces_access_key
DO_SPACES_SECRET_KEY     = your_spaces_secret_key
```

### 2. Workflow Triggers

```yaml
# Runs on:
- Push to main/develop (auto-apply on main)
- Pull requests (plan only)
- Manual dispatch (for destroy)
```

### 3. Manual Workflow Dispatch

```bash
# Via GitHub UI
# Go to: Actions → Terraform CI/CD → Run workflow

# Via GitHub CLI
gh workflow run terraform.yml
```

---

## 🧪 Testing

### Validate Configuration

```bash
# Format check
terraform fmt -check -recursive

# Validate syntax
terraform validate

# Check for issues
terraform plan
```

### Cost Estimation

```bash
# Install infracost
brew install infracost

# Estimate costs
infracost breakdown --path .
```

### Security Scanning

```bash
# Install tfsec
brew install tfsec

# Scan for security issues
tfsec .
```

---

## 📦 Resource Sizing

### Droplet Sizes

| Size | vCPUs | RAM | Price/mo |
|------|-------|-----|----------|
| `s-1vcpu-1gb` | 1 | 1 GB | $6 |
| `s-2vcpu-2gb` | 2 | 2 GB | $12 |
| `s-2vcpu-4gb` | 2 | 4 GB | $24 |
| `s-4vcpu-8gb` | 4 | 8 GB | $48 |

### Database Sizes

| Size | vCPUs | RAM | Price/mo |
|------|-------|-----|----------|
| `db-s-1vcpu-1gb` | 1 | 1 GB | $15 |
| `db-s-2vcpu-4gb` | 2 | 4 GB | $60 |
| `db-s-4vcpu-8gb` | 4 | 8 GB | $120 |

### Estimated Monthly Cost

- **Minimal**: ~$100/month (1 droplet, 1 DB node, 1 Redis)
- **Production**: ~$200/month (2 droplets, 2 DB nodes, 1 Redis, LB)
- **High Availability**: ~$400/month (4 droplets, 3 DB nodes, 2 Redis, LB)

---

## 🛠️ Common Tasks

### Scale Droplet

```bash
# Update terraform.tfvars
droplet_size = "s-4vcpu-8gb"

# Apply changes
terraform apply
```

### Add SSH Key

```bash
# Get SSH key ID
doctl compute ssh-key list

# Add to terraform.tfvars
ssh_keys = ["12345678"]

# Apply
terraform apply
```

### Enable Backups

```bash
# Update terraform.tfvars
enable_backups = true

# Apply
terraform apply
```

### Update Database Size

```bash
# Update terraform.tfvars
db_cluster_size = "db-s-4vcpu-8gb"

# Apply (will cause downtime)
terraform apply
```

---

## 🔄 Disaster Recovery

### Backup State

```bash
# Download current state
terraform state pull > terraform.tfstate.backup

# Upload to Spaces
doctl spaces cp terraform.tfstate.backup s3://tfvisualizer-terraform-state/backups/
```

### Restore State

```bash
# Download backup
doctl spaces cp s3://tfvisualizer-terraform-state/backups/terraform.tfstate.backup .

# Push to Terraform
terraform state push terraform.tfstate.backup
```

### Import Existing Resources

```bash
# Import droplet
terraform import digitalocean_droplet.app 123456789

# Import database
terraform import digitalocean_database_cluster.postgres abc123-def456-ghi789
```

---

## 🗑️ Cleanup

### Destroy Specific Resources

```bash
# Destroy single resource
terraform destroy -target=digitalocean_droplet.app

# Destroy multiple resources
terraform destroy -target=digitalocean_database_cluster.redis -target=digitalocean_loadbalancer.public
```

### Destroy Everything

```bash
# Plan destroy
terraform plan -destroy

# Destroy all resources
terraform destroy

# Auto-approve (dangerous!)
terraform destroy -auto-approve
```

---

## 🐛 Troubleshooting

### State Lock Issues

```bash
# Force unlock (use with caution)
terraform force-unlock LOCK_ID
```

### Backend Connection Issues

```bash
# Verify credentials
doctl auth init

# Test Spaces access
doctl spaces ls

# Re-initialize backend
rm -rf .terraform
terraform init -reconfigure
```

### Provider Issues

```bash
# Upgrade providers
terraform init -upgrade

# Lock provider versions
terraform providers lock
```

### API Rate Limits

```bash
# Check rate limit status
doctl auth list

# Wait and retry
sleep 60
terraform apply
```

---

## 📚 Additional Resources

- [DigitalOcean Terraform Provider](https://registry.terraform.io/providers/digitalocean/digitalocean/latest/docs)
- [DigitalOcean API Documentation](https://docs.digitalocean.com/reference/api/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [DigitalOcean Community Tutorials](https://www.digitalocean.com/community/tags/terraform)

---

## 🤝 Contributing

1. Create feature branch
2. Make changes
3. Test with `terraform plan`
4. Submit pull request
5. CI/CD will run `terraform plan`

---

**Infrastructure managed with Terraform 1.6.0+**
