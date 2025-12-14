# DigitalOcean Kubernetes Cluster
resource "digitalocean_kubernetes_cluster" "main" {
  name     = "${var.project_name}-${var.environment}-k8s"
  region   = var.region
  version  = var.kubernetes_version
  vpc_uuid = digitalocean_vpc.main.id

  node_pool {
    name = "${var.project_name}-worker-pool"
    # When `kubernetes_quick_provision` is true create a smaller/faster node pool
    size       = var.kubernetes_quick_provision ? var.kubernetes_quick_node_size : var.kubernetes_node_size
    node_count = var.kubernetes_quick_provision ? var.kubernetes_quick_node_count : var.kubernetes_node_count
    auto_scale = var.kubernetes_quick_provision ? false : var.kubernetes_autoscale
    min_nodes  = var.kubernetes_quick_provision ? var.kubernetes_quick_node_count : var.kubernetes_min_nodes
    max_nodes  = var.kubernetes_quick_provision ? var.kubernetes_quick_node_count : var.kubernetes_max_nodes
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

# Secret for environment variables - NOW MANAGED BY SEALED SECRETS
# The secret "tfvisualizer-config" is created from a SealedSecret that is deployed
# by the GitHub Actions workflow (.github/workflows/terraform.yml)
#
# The SealedSecret is automatically unsealed by the sealed-secrets controller
# into a regular Kubernetes secret that can be referenced by pods.
#
# To update secrets:
# 1. Update the secret values in GitHub Secrets
# 2. Push to main branch or manually trigger the workflow
# 3. The workflow will create a new sealed secret and deploy it
#
# For local development or manual secret updates, use:
# scripts/create-sealed-secret.sh
#
# Reference to the secret (managed externally by SealedSecret)
# Terraform does not create this secret - it's created by the sealed-secrets controller
# when it unseals the SealedSecret resource deployed by GitHub Actions

# Data source to reference the existing secret (optional - for validation)
# Uncomment if you want Terraform to validate the secret exists
# data "kubernetes_secret" "app_config" {
#   metadata {
#     name      = "tfvisualizer-config"
#     namespace = kubernetes_namespace.tfvisualizer.metadata[0].name
#   }
#   depends_on = [
#     helm_release.sealed_secrets
#   ]
# }

# Reference existing secret (created externally by SealedSecrets or manually)
# Using data source instead of resource to avoid "already exists" error
data "kubernetes_secret" "app_config" {
  metadata {
    name      = "tfvisualizer-config"
    namespace = kubernetes_namespace.tfvisualizer.metadata[0].name
  }
}

# If the secret doesn't exist yet, you can create it manually or import it:
#   kubectl create secret generic tfvisualizer-config -n tfvisualizer --from-literal=PORT=8080
# Or uncomment the resource below and import it:
#   terraform import kubernetes_secret.app_config tfvisualizer/tfvisualizer-config
#
# resource "kubernetes_secret" "app_config" {
#   metadata {
#     name      = "tfvisualizer-config"
#     namespace = kubernetes_namespace.tfvisualizer.metadata[0].name
#   }
#
#   data = {
#     FLASK_ENV              = var.environment
#     PORT                   = "8080"
#     SECRET_KEY             = var.secret_key
#     JWT_SECRET             = var.jwt_secret
#     DATABASE_URL           = "postgresql://tfuser:${var.postgres_password}@postgres.tfvisualizer.svc.cluster.local:5432/tfvisualizer"
#     DB_HOST                = "postgres.tfvisualizer.svc.cluster.local"
#     DB_PORT                = "5432"
#     DB_NAME                = "tfvisualizer"
#     DB_USER                = "tfuser"
#     DB_PASSWORD            = var.postgres_password
#     REDIS_URL              = "redis://:${var.redis_password}@redis.tfvisualizer.svc.cluster.local:6379"
#     REDIS_HOST             = "redis.tfvisualizer.svc.cluster.local"
#     REDIS_PORT             = "6379"
#     REDIS_PASSWORD         = var.redis_password
#     STRIPE_SECRET_KEY      = var.stripe_secret_key
#     STRIPE_PUBLISHABLE_KEY = var.stripe_publishable_key
#     STRIPE_WEBHOOK_SECRET  = var.stripe_webhook_secret
#     STRIPE_PRICE_ID_PRO    = var.stripe_price_id_pro
#     STRIPE_SUCCESS_URL     = "https://${var.domain_name}/subscription/success"
#     STRIPE_CANCEL_URL      = "https://${var.domain_name}/pricing"
#     S3_BUCKET_NAME         = digitalocean_spaces_bucket.files.name
#     AWS_ACCESS_KEY_ID      = var.spaces_access_key
#     AWS_SECRET_ACCESS_KEY  = var.spaces_secret_key
#     AWS_REGION             = var.region
#     GOOGLE_CLIENT_ID       = var.google_client_id
#     GOOGLE_CLIENT_SECRET   = var.google_client_secret
#   }
#
#   type = "Opaque"
# }

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
              # Reference the secret created by the SealedSecret controller
              name = "tfvisualizer-config"
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

# Vertical Pod Autoscaler
resource "kubernetes_manifest" "app_vpa" {
  manifest = {
    apiVersion = "autoscaling.k8s.io/v1"
    kind       = "VerticalPodAutoscaler"
    metadata = {
      name      = "tfvisualizer-vpa"
      namespace = kubernetes_namespace.tfvisualizer.metadata[0].name
    }
    spec = {
      targetRef = {
        apiVersion = "apps/v1"
        kind       = "Deployment"
        name       = kubernetes_deployment.app.metadata[0].name
      }
      updatePolicy = {
        updateMode = var.vpa_update_mode
      }
      resourcePolicy = {
        containerPolicies = [
          {
            containerName = "tfvisualizer"
            minAllowed = {
              cpu    = var.vpa_min_cpu
              memory = var.vpa_min_memory
            }
            maxAllowed = {
              cpu    = var.vpa_max_cpu
              memory = var.vpa_max_memory
            }
            controlledResources = ["cpu", "memory"]
          }
        ]
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
