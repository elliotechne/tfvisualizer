output "kubernetes_cluster_id" {
  description = "Kubernetes cluster ID"
  value       = digitalocean_kubernetes_cluster.main.id
}

output "kubernetes_cluster_endpoint" {
  description = "Kubernetes cluster endpoint"
  value       = digitalocean_kubernetes_cluster.main.endpoint
}

output "kubernetes_cluster_name" {
  description = "Kubernetes cluster name"
  value       = digitalocean_kubernetes_cluster.main.name
}

output "loadbalancer_ip" {
  description = "IP address of the Kubernetes load balancer"
  value       = try(kubernetes_service.app.status.0.load_balancer.0.ingress.0.ip, "pending")
}

output "kubeconfig" {
  description = "Kubernetes config for kubectl"
  value       = digitalocean_kubernetes_cluster.main.kube_config[0].raw_config
  sensitive   = true
}

output "database_host" {
  description = "PostgreSQL database host (Kubernetes service)"
  value       = "postgres.${kubernetes_namespace.tfvisualizer.metadata[0].name}.svc.cluster.local"
}

output "database_port" {
  description = "PostgreSQL database port"
  value       = 5432
}

output "database_name" {
  description = "PostgreSQL database name"
  value       = "tfvisualizer"
}

output "database_user" {
  description = "PostgreSQL database user"
  value       = "tfuser"
}

output "database_uri" {
  description = "PostgreSQL connection URI (from within cluster)"
  value       = "postgresql://tfuser:${var.postgres_password}@postgres.${kubernetes_namespace.tfvisualizer.metadata[0].name}.svc.cluster.local:5432/tfvisualizer"
  sensitive   = true
}

output "redis_host" {
  description = "Redis host (Kubernetes service)"
  value       = "redis.${kubernetes_namespace.tfvisualizer.metadata[0].name}.svc.cluster.local"
}

output "redis_port" {
  description = "Redis port"
  value       = 6379
}

output "redis_uri" {
  description = "Redis connection URI (from within cluster)"
  value       = "redis://:${var.redis_password}@redis.${kubernetes_namespace.tfvisualizer.metadata[0].name}.svc.cluster.local:6379"
  sensitive   = true
}

output "spaces_bucket_name" {
  description = "Spaces bucket name"
  value       = digitalocean_spaces_bucket.files.name
}

output "spaces_bucket_endpoint" {
  description = "Spaces bucket endpoint"
  value       = digitalocean_spaces_bucket.files.bucket_domain_name
}

output "domain_name" {
  description = "Application domain name"
  value       = digitalocean_domain.main.name
}

output "vpc_id" {
  description = "VPC ID"
  value       = digitalocean_vpc.main.id
}

output "project_id" {
  description = "Project ID"
  value       = digitalocean_project.main.id
}

