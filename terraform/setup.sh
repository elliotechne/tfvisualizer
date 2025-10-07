#!/bin/bash
# Terraform Setup Script for TFVisualizer on DigitalOcean

set -e

echo "========================================="
echo "TFVisualizer Terraform Setup"
echo "========================================="
echo ""

# Check if required tools are installed
check_requirements() {
    echo "Checking requirements..."

    if ! command -v terraform &> /dev/null; then
        echo "❌ Terraform not found. Please install Terraform 1.6.0+"
        echo "   https://developer.hashicorp.com/terraform/downloads"
        exit 1
    fi

    echo "✓ Terraform $(terraform version -json | jq -r '.terraform_version') installed"

    if ! command -v doctl &> /dev/null; then
        echo "⚠️  doctl not found (optional but recommended)"
        echo "   Install: https://docs.digitalocean.com/reference/doctl/how-to/install/"
    else
        echo "✓ doctl installed"
    fi

    echo ""
}

# Check environment variables
check_env_vars() {
    echo "Checking environment variables..."

    if [ -z "$DIGITALOCEAN_TOKEN" ]; then
        echo "❌ DIGITALOCEAN_TOKEN not set"
        echo "   Get token: https://cloud.digitalocean.com/account/api/tokens"
        echo "   export DIGITALOCEAN_TOKEN='dop_v1_your_token'"
        exit 1
    fi
    echo "✓ DIGITALOCEAN_TOKEN is set"

    if [ -z "$DO_SPACES_ACCESS_KEY" ] || [ -z "$DO_SPACES_SECRET_KEY" ]; then
        echo "❌ DO_SPACES credentials not set"
        echo "   Get credentials: https://cloud.digitalocean.com/account/api/spaces"
        echo "   export DO_SPACES_ACCESS_KEY='your_access_key'"
        echo "   export DO_SPACES_SECRET_KEY='your_secret_key'"
        exit 1
    fi
    echo "✓ DO_SPACES credentials are set"

    echo ""
}

# Create Spaces bucket for state
create_state_bucket() {
    echo "Checking Terraform state bucket..."

    BUCKET_NAME="tfvisualizer-terraform-state"
    REGION="nyc3"

    if command -v doctl &> /dev/null; then
        if doctl spaces ls | grep -q "$BUCKET_NAME"; then
            echo "✓ Spaces bucket '$BUCKET_NAME' already exists"
        else
            echo "Creating Spaces bucket '$BUCKET_NAME'..."
            doctl spaces create "$BUCKET_NAME" --region "$REGION"
            echo "✓ Spaces bucket created"
        fi
    else
        echo "⚠️  Cannot verify Spaces bucket (doctl not installed)"
        echo "   Please create bucket manually: $BUCKET_NAME"
    fi

    echo ""
}

# Create terraform.tfvars if it doesn't exist
create_tfvars() {
    if [ ! -f terraform.tfvars ]; then
        echo "Creating terraform.tfvars from example..."
        cp terraform.tfvars.example terraform.tfvars

        # Replace token in tfvars
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/dop_v1_your_token_here/$DIGITALOCEAN_TOKEN/" terraform.tfvars
        else
            sed -i "s/dop_v1_your_token_here/$DIGITALOCEAN_TOKEN/" terraform.tfvars
        fi

        echo "✓ terraform.tfvars created"
        echo "⚠️  Please edit terraform.tfvars to configure your infrastructure"
        echo ""
    else
        echo "✓ terraform.tfvars already exists"
        echo ""
    fi
}

# Initialize Terraform
init_terraform() {
    echo "Initializing Terraform..."

    terraform init \
        -backend-config="access_key=$DO_SPACES_ACCESS_KEY" \
        -backend-config="secret_key=$DO_SPACES_SECRET_KEY"

    echo ""
    echo "✓ Terraform initialized successfully"
    echo ""
}

# Validate configuration
validate_terraform() {
    echo "Validating Terraform configuration..."

    terraform fmt -check || terraform fmt
    terraform validate

    echo "✓ Terraform configuration is valid"
    echo ""
}

# Main execution
main() {
    check_requirements
    check_env_vars
    create_state_bucket
    create_tfvars
    init_terraform
    validate_terraform

    echo "========================================="
    echo "✅ Setup Complete!"
    echo "========================================="
    echo ""
    echo "Next steps:"
    echo "  1. Review and edit terraform.tfvars"
    echo "  2. Run: terraform plan"
    echo "  3. Run: terraform apply"
    echo ""
    echo "For help, see: README.md"
    echo ""
}

# Run main function
main
