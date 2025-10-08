# VPC - test 
resource "digitalocean_vpc" "main" {
  name     = "${var.project_name}-${var.environment}-vpc"
  region   = var.region
  ip_range = "10.2.0.0/16"
}

# Kubernetes cluster is defined in kubernetes.tf
# PostgreSQL and Redis databases are defined in databases.tf (running on DOKS)

# Spaces Bucket for file storage
resource "digitalocean_spaces_bucket" "files" {
  name   = "${var.project_name}-${var.environment}-files"
  region = var.region
  acl    = "private"

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD", "POST", "PUT"]
    allowed_origins = ["https://${var.domain_name}"]
    max_age_seconds = 3600
  }
}

# Load Balancer is automatically created by nginx-ingress-controller (see nginx-ingress.tf)
# SSL certificates are managed by cert-manager with ZeroSSL (see cert-manager.tf)

# Domain
resource "digitalocean_domain" "main" {
  name = var.domain_name
}

# DNS records are now managed by external-dns (see external-dns.tf)
# external-dns will automatically create A records for Ingress resources

# Project to organize resources
resource "digitalocean_project" "main" {
  name        = "${var.project_name}-${var.environment}"
  description = "TFVisualizer ${var.environment} infrastructure"
  purpose     = "Web Application"
  environment = title(var.environment)

  resources = [
    digitalocean_kubernetes_cluster.main.urn,
    digitalocean_domain.main.urn,
    digitalocean_spaces_bucket.files.urn,
  ]
}

# Kubernetes cluster monitoring is handled by DOKS built-in monitoring
