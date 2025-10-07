# VPC 
resource "digitalocean_vpc" "main" {
  name     = "${var.project_name}-${var.environment}-vpc"
  region   = var.region
  ip_range = "10.0.0.0/16"
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

# Load Balancer is automatically created by Kubernetes Service (see kubernetes.tf)

# SSL Certificate (Let's Encrypt)
resource "digitalocean_certificate" "cert" {
  name    = "${var.project_name}-${var.environment}-cert"
  type    = "lets_encrypt"
  domains = [var.domain_name, "www.${var.domain_name}"]

  lifecycle {
    create_before_destroy = true
  }
}

# Domain
resource "digitalocean_domain" "main" {
  name = var.domain_name
}

# DNS A Record pointing to Kubernetes Load Balancer
resource "digitalocean_record" "root" {
  domain = digitalocean_domain.main.id
  type   = "A"
  name   = "@"
  value  = kubernetes_service.app.status.0.load_balancer.0.ingress.0.ip
  ttl    = 300

  depends_on = [kubernetes_service.app]
}

# DNS A Record for www subdomain
resource "digitalocean_record" "www" {
  domain = digitalocean_domain.main.id
  type   = "A"
  name   = "www"
  value  = kubernetes_service.app.status.0.load_balancer.0.ingress.0.ip
  ttl    = 300

  depends_on = [kubernetes_service.app]
}

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
