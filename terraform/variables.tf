variable "do_token" {
  description = "DigitalOcean API Token"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "DigitalOcean region"
  type        = string
  default     = "nyc3"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "tfvisualizer"
}

variable "environment" {
  description = "Environment (production, staging, development)"
  type        = string
  default     = "production"
}

# Kubernetes Cluster Configuration
variable "kubernetes_version" {
  description = "Kubernetes version for DOKS cluster"
  type        = string
  default     = "1.33.1-do.4"
}

variable "kubernetes_node_size" {
  description = "Node size for Kubernetes worker nodes"
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "kubernetes_node_count" {
  description = "Initial number of nodes in the cluster"
  type        = number
  default     = 2
}

variable "kubernetes_autoscale" {
  description = "Enable autoscaling for node pool"
  type        = bool
  default     = true
}

variable "kubernetes_min_nodes" {
  description = "Minimum nodes for autoscaling"
  type        = number
  default     = 2
}

variable "kubernetes_max_nodes" {
  description = "Maximum nodes for autoscaling"
  type        = number
  default     = 2
}

# PostgreSQL Configuration (running on Kubernetes)
variable "postgres_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "postgres_storage_size" {
  description = "PostgreSQL persistent volume size"
  type        = string
  default     = "20Gi"
}

# Redis Configuration (running on Kubernetes)
variable "redis_password" {
  description = "Redis password"
  type        = string
  sensitive   = true
}

variable "redis_storage_size" {
  description = "Redis persistent volume size"
  type        = string
  default     = "5Gi"
}

variable "enable_backups" {
  description = "Enable automated backups"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Enable monitoring"
  type        = bool
  default     = true
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "alert_email" {
  description = "Email for monitoring alerts"
  type        = string
  default     = "alerts@tfvisualizer.com"
}

# Application Configuration
variable "app_replicas" {
  description = "Number of application replicas"
  type        = number
  default     = 2
}

variable "app_min_replicas" {
  description = "Minimum replicas for HPA"
  type        = number
  default     = 2
}

variable "app_max_replicas" {
  description = "Maximum replicas for HPA"
  type        = number
  default     = 10
}

variable "app_cpu_request" {
  description = "CPU request for application pods"
  type        = string
  default     = "250m"
}

variable "app_cpu_limit" {
  description = "CPU limit for application pods"
  type        = string
  default     = "1000m"
}

variable "app_memory_request" {
  description = "Memory request for application pods"
  type        = string
  default     = "512Mi"
}

variable "app_memory_limit" {
  description = "Memory limit for application pods"
  type        = string
  default     = "2Gi"
}

# Docker Registry Configuration
variable "docker_registry" {
  description = "Docker registry URL"
  type        = string
  default     = "ghcr.io"
}

variable "docker_image" {
  description = "Docker image name (without registry)"
  type        = string
  default     = "elliotechne/tfvisualizer"
}

variable "docker_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "docker_registry_username" {
  description = "Docker registry username"
  type        = string
  default     = ""
  sensitive   = true
}

variable "docker_registry_password" {
  description = "Docker registry password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "docker_registry_email" {
  description = "Docker registry email"
  type        = string
  default     = ""
}

# Secrets Configuration
variable "secret_key" {
  description = "Flask secret key"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT secret key"
  type        = string
  sensitive   = true
}

variable "stripe_secret_key" {
  description = "Stripe secret key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "stripe_publishable_key" {
  description = "Stripe publishable key"
  type        = string
  default     = ""
}

variable "stripe_webhook_secret" {
  description = "Stripe webhook secret"
  type        = string
  default     = ""
  sensitive   = true
}

variable "stripe_price_id_pro" {
  description = "Stripe price ID for Pro tier"
  type        = string
  default     = ""
}

variable "spaces_access_key" {
  description = "DigitalOcean Spaces access key"
  type        = string
  sensitive   = true
}

variable "spaces_secret_key" {
  description = "DigitalOcean Spaces secret key"
  type        = string
  sensitive   = true
}

variable "letsencrypt_email" {
  description = "LE email address"
  type        = string
  sensitive   = true
}

# OAuth Configuration
variable "google_client_id" {
  description = "Google OAuth Client ID"
  type        = string
  default     = ""
}

variable "google_client_secret" {
  description = "Google OAuth Client Secret"
  type        = string
  default     = ""
  sensitive   = true
}
# Grafana admin credentials (used by the grafana module)
variable "grafana_admin_user" {
  description = "Grafana admin username"
  type        = string
  default     = "admin"
}

variable "grafana_admin_password" {
  description = "Grafana admin password (sensitive). Provide via terraform.tfvars or environment variables"
  type        = string
  sensitive   = true
}

# Quick provisioning option: create a smaller/fewer-node cluster to speed up initial creation
variable "kubernetes_quick_provision" {
  description = "When true, create a smaller/faster initial Kubernetes cluster (1 small node). Useful for development or faster provisioning."
  type        = bool
  default     = false
}

variable "kubernetes_quick_node_size" {
  description = "Node size to use when quick provision is enabled"
  type        = string
  default     = "s-1vcpu-2gb"
}

variable "kubernetes_quick_node_count" {
  description = "Initial node count when quick provision is enabled"
  type        = number
  default     = 1
}
