terraform {
  required_version = ">= 1.0"

  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }

  # Optional: Configure remote backend for state
  backend "s3" {
    bucket                      = "tfvisualizer"
    key                         = "staging.tfstate"
    region                      = "us-east-1" # Required but ignored by DO Spaces
    endpoints                   = { s3 = "https://nyc3.digitaloceanspaces.com" }
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    use_path_style              = true
    skip_requesting_account_id  = true
  }
}

provider "digitalocean" {
  token = var.do_token
}

provider "kubernetes" {
  host  = digitalocean_kubernetes_cluster.tfvisualizer.endpoint
  token = digitalocean_kubernetes_cluster.tfvisualizer.kube_config[0].token
  cluster_ca_certificate = base64decode(
    digitalocean_kubernetes_cluster.tfvisualizer.kube_config[0].cluster_ca_certificate
  )
}
