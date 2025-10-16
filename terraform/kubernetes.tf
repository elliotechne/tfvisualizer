# DigitalOcean Kubernetes Cluster
resource "digitalocean_kubernetes_cluster" "main" {
  name     = "${var.project_name}-${var.environment}-k8s"
  region   = var.region
  version  = var.kubernetes_version
  vpc_uuid = digitalocean_vpc.main.id

  node_pool {
    name       = "${var.project_name}-worker-pool"
    size       = var.kubernetes_node_size
    node_count = var.kubernetes_node_count
    auto_scale = var.kubernetes_autoscale
    min_nodes  = var.kubernetes_min_nodes
    max_nodes  = var.kubernetes_max_nodes
    tags       = ["${var.project_name}", "${var.environment}", "worker"]
  }

  tags = ["${var.project_name}", "${var.environment}", "kubernetes"]
}

# Kubernetes provider configuration
provider "kubernetes" {
  host  = digitalocean_kubernetes_cluster.main.endpoint
  token = digitalocean_kubernetes_cluster.main.kube_config[0].token
  cluster_ca_certificate = base64decode(
    digitalocean_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate
  )
}

# Helm provider configuration
provider "helm" {
  kubernetes {
    host  = digitalocean_kubernetes_cluster.main.endpoint
    token = digitalocean_kubernetes_cluster.main.kube_config[0].token
    cluster_ca_certificate = base64decode(
      digitalocean_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate
    )
  }
}

# Kubectl provider configuration
provider "kubectl" {
  host  = digitalocean_kubernetes_cluster.main.endpoint
  token = digitalocean_kubernetes_cluster.main.kube_config[0].token
  cluster_ca_certificate = base64decode(
    digitalocean_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate
  )
  load_config_file = false
}

# Namespace for TFVisualizer
resource "kubernetes_namespace" "tfvisualizer" {
  metadata {
    name = var.project_name
    labels = {
      name        = var.project_name
      environment = var.environment
    }
  }
}

# Secret for environment variables
resource "kubernetes_secret" "app_config" {
  metadata {
    name      = "tfvisualizer-config"
    namespace = kubernetes_namespace.tfvisualizer.metadata[0].name
  }

  data = {
    FLASK_ENV              = var.environment
    PORT                   = "8080"
    SECRET_KEY             = var.secret_key
    JWT_SECRET             = var.jwt_secret
    DATABASE_URL           = "postgresql://tfuser:${var.postgres_password}@postgres.tfvisualizer.svc.cluster.local:5432/tfvisualizer"
    DB_HOST                = "postgres.tfvisualizer.svc.cluster.local"
    DB_PORT                = "5432"
    DB_NAME                = "tfvisualizer"
    DB_USER                = "tfuser"
    DB_PASSWORD            = var.postgres_password
    REDIS_URL              = "redis://:${var.redis_password}@redis.tfvisualizer.svc.cluster.local:6379"
    REDIS_HOST             = "redis.tfvisualizer.svc.cluster.local"
    REDIS_PORT             = "6379"
    REDIS_PASSWORD         = var.redis_password
    STRIPE_SECRET_KEY      = var.stripe_secret_key
    STRIPE_PUBLISHABLE_KEY = var.stripe_publishable_key
    STRIPE_WEBHOOK_SECRET  = var.stripe_webhook_secret
    STRIPE_PRICE_ID_PRO    = var.stripe_price_id_pro
    STRIPE_SUCCESS_URL     = "https://${var.domain_name}/subscription/success"
    STRIPE_CANCEL_URL      = "https://${var.domain_name}/pricing"
    S3_BUCKET_NAME         = digitalocean_spaces_bucket.files.name
    AWS_ACCESS_KEY_ID      = var.spaces_access_key
    AWS_SECRET_ACCESS_KEY  = var.spaces_secret_key
    AWS_REGION             = var.region
    GOOGLE_CLIENT_ID       = var.google_client_id
    GOOGLE_CLIENT_SECRET   = var.google_client_secret
    ANTHROPIC_API_KEY      = var.anthropic_api_key
  }

  type = "Opaque"
}

# ConfigMap for non-sensitive configuration
resource "kubernetes_config_map" "app_config" {
  metadata {
    name      = "tfvisualizer-config"
    namespace = kubernetes_namespace.tfvisualizer.metadata[0].name
  }

  data = {
    CORS_ORIGINS = "https://${var.domain_name}"
    LOG_LEVEL    = "INFO"
  }
}

# Deployment for TFVisualizer application
resource "kubernetes_deployment" "app" {
  metadata {
    name      = "tfvisualizer-app"
    namespace = kubernetes_namespace.tfvisualizer.metadata[0].name
    labels = {
      app         = "tfvisualizer"
      environment = var.environment
    }
  }

  spec {
    replicas = var.app_replicas

    selector {
      match_labels = {
        app = "tfvisualizer"
      }
    }

    template {
      metadata {
        labels = {
          app         = "tfvisualizer"
          environment = var.environment
        }
      }

      spec {
        container {
          name              = "tfvisualizer"
          image             = "${var.docker_registry}/${var.docker_image}:${var.docker_tag}"
          image_pull_policy = "Always"

          port {
            container_port = 8080
            name           = "http"
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.app_config.metadata[0].name
            }
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.app_config.metadata[0].name
            }
          }

          resources {
            requests = {
              cpu    = var.app_cpu_request
              memory = var.app_memory_request
            }
            limits = {
              cpu    = var.app_cpu_limit
              memory = var.app_memory_limit
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 3
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 15
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 2
          }

          startup_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 0
            period_seconds        = 3
            timeout_seconds       = 2
            failure_threshold     = 30
          }
        }

        image_pull_secrets {
          name = kubernetes_secret.docker_registry.metadata[0].name
        }
      }
    }

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = "1"
        max_unavailable = "1"
      }
    }
  }
}

# Service for TFVisualizer application
resource "kubernetes_service" "app" {
  metadata {
    name      = "tfvisualizer-service"
    namespace = kubernetes_namespace.tfvisualizer.metadata[0].name
  }

  spec {
    selector = {
      app = "tfvisualizer"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 8080
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

# Horizontal Pod Autoscaler
resource "kubernetes_horizontal_pod_autoscaler_v2" "app" {
  metadata {
    name      = "tfvisualizer-hpa"
    namespace = kubernetes_namespace.tfvisualizer.metadata[0].name
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.app.metadata[0].name
    }

    min_replicas = var.app_min_replicas
    max_replicas = var.app_max_replicas

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }

    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = 80
        }
      }
    }
  }
}

# Docker registry secret (if using private registry)
resource "kubernetes_secret" "docker_registry" {
  metadata {
    name      = "docker-registry-credentials"
    namespace = kubernetes_namespace.tfvisualizer.metadata[0].name
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "${var.docker_registry}" = {
          username = var.docker_registry_username
          password = var.docker_registry_password
          email    = var.docker_registry_email
          auth     = base64encode("${var.docker_registry_username}:${var.docker_registry_password}")
        }
      }
    })
  }
}

# PodDisruptionBudget for high availability
resource "kubernetes_pod_disruption_budget_v1" "app" {
  metadata {
    name      = "tfvisualizer-pdb"
    namespace = kubernetes_namespace.tfvisualizer.metadata[0].name
  }

  spec {
    max_unavailable = "1"
    selector {
      match_labels = {
        app = "tfvisualizer"
      }
    }
  }
}

# NetworkPolicy for security
resource "kubernetes_network_policy" "app" {
  metadata {
    name      = "tfvisualizer-network-policy"
    namespace = kubernetes_namespace.tfvisualizer.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        app = "tfvisualizer"
      }
    }

    policy_types = ["Ingress", "Egress"]

    ingress {
      # Allow traffic from nginx-ingress namespace
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "ingress-nginx"
          }
        }
      }
      ports {
        port     = "8080"
        protocol = "TCP"
      }
    }

    ingress {
      # Allow traffic from within same namespace
      from {
        namespace_selector {
          match_labels = {
            name = kubernetes_namespace.tfvisualizer.metadata[0].name
          }
        }
      }
      ports {
        port     = "8080"
        protocol = "TCP"
      }
    }

    egress {
      # Allow DNS
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "kube-system"
          }
        }
      }
      ports {
        port     = "53"
        protocol = "UDP"
      }
    }

    egress {
      # Allow DNS TCP
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "kube-system"
          }
        }
      }
      ports {
        port     = "53"
        protocol = "TCP"
      }
    }

    egress {
      # Allow connections to PostgreSQL and Redis in same namespace
      to {
        pod_selector {
          match_labels = {}
        }
      }
    }

    egress {
      # Allow all other egress (external APIs)
      to {
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }
    }
  }
}

# PostgreSQL and Redis run as StatefulSets within the Kubernetes cluster
# No external firewall rules needed - see databases.tf
