terraform {
  backend "s3" {
    # DigitalOcean Spaces backend configuration
    # Spaces is S3-compatible
    endpoint                    = "nyc3.digitaloceanspaces.com"
    region                      = "us-east-1" # Required but not used by Spaces
    bucket                      = "tfvisualizer-terraform-state"
    key                         = "production/terraform.tfstate"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true

    # Access credentials should be passed via:
    # - Backend config flags during init
    # - Environment variables: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
    # access_key = "DO_SPACES_ACCESS_KEY"
    # secret_key = "DO_SPACES_SECRET_KEY"
  }

  required_version = ">= 1.6.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.34.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24.0"
    }
  }
}

# Configure the DigitalOcean Provider
provider "digitalocean" {
  token = var.do_token
}
