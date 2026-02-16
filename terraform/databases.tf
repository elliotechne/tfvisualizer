# PostgreSQL initialization script ConfigMap 
resource "kubernetes_config_map" "postgres_init" {
  metadata {
    name      = "postgres-init"
    namespace = kubernetes_namespace.tfvisualizer.metadata[0].name
  }

  data = {
    "01-create-roles.sh" = <<-EOT
      #!/bin/bash
      set -e

      # Create postgres superuser role
      psql -v ON_ERROR_STOP=0 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        CREATE ROLE postgres WITH SUPERUSER LOGIN PASSWORD '${var.postgres_password}';
        GRANT ALL PRIVILEGES ON DATABASE tfvisualizer TO postgres;
      EOSQL

      echo "PostgreSQL roles created successfully"
    EOT
  }
}

# PostgreSQL StatefulSet
resource "kubernetes_stateful_set" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.tfvisualizer.metadata[0].name
    labels = {
      app = "postgres"
    }
  }

  spec {
    service_name = "postgres"
    replicas     = 1

    selector {
      match_labels = {
        app = "postgres"
      }
    }

    template {
      metadata {
        labels = {
          app = "postgres"
        }
      }

      spec {
        container {
          name  = "postgres"
          image = "postgres:15-alpine"

          port {
            container_port = 5432
            name           = "postgres"
          }

          env {
            name  = "POSTGRES_DB"
            value = "tfvisualizer"
          }

          env {
            name  = "POSTGRES_USER"
            value = "tfuser"
          }

          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.database_credentials.metadata[0].name
                key  = "postgres-password"
              }
            }
          }

          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data/pgdata"
          }

          resources {
            requests = {
              cpu    = "250m"
              memory = "512Mi"
            }
            limits = {
              cpu    = "1000m"
              memory = "2Gi"
            }
          }

          volume_mount {
            name       = "postgres-storage"
            mount_path = "/var/lib/postgresql/data"
          }

          volume_mount {
            name       = "init-script"
            mount_path = "/docker-entrypoint-initdb.d"
            read_only  = true
          }

          lifecycle {
            post_start {
              exec {
                command = [
                  "/bin/sh",
                  "-c",
                  "sleep 20 && PGPASSWORD=$POSTGRES_PASSWORD psql -h localhost -U $POSTGRES_USER -d $POSTGRES_DB -c \"CREATE DATABASE root;\" || true && PGPASSWORD=$POSTGRES_PASSWORD psql -h localhost -U $POSTGRES_USER -d $POSTGRES_DB -c \"DO \\$\\$ BEGIN IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'root') THEN CREATE ROLE root WITH SUPERUSER LOGIN PASSWORD '$POSTGRES_PASSWORD'; GRANT ALL PRIVILEGES ON DATABASE $POSTGRES_DB TO root; GRANT ALL PRIVILEGES ON DATABASE root TO root; END IF; END \\$\\$;\" || true"
                ]
              }
            }
          }

          liveness_probe {
            exec {
              command = ["pg_isready", "-h", "localhost"]
            }
            initial_delay_seconds = 60
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 6
          }

          readiness_probe {
            exec {
              command = ["pg_isready", "-h", "localhost"]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 6
          }
        }

        volume {
          name = "init-script"
          config_map {
            name         = kubernetes_config_map.postgres_init.metadata[0].name
            default_mode = "0755"
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "postgres-storage"
      }

      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = "do-block-storage"

        resources {
          requests = {
            storage = var.postgres_storage_size
          }
        }
      }
    }
  }
}

# PostgreSQL Service
resource "kubernetes_service" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.tfvisualizer.metadata[0].name
    labels = {
      app = "postgres"
    }
  }

  spec {
    selector = {
      app = "postgres"
    }

    port {
      name        = "postgres"
      port        = 5432
      target_port = 5432
      protocol    = "TCP"
    }

    type       = "ClusterIP"
    cluster_ip = "None" # Headless service for StatefulSet
  }
}

# Redis StatefulSet
resource "kubernetes_stateful_set" "redis" {
  metadata {
    name      = "redis"
    namespace = kubernetes_namespace.tfvisualizer.metadata[0].name
    labels = {
      app = "redis"
    }
  }

  spec {
    service_name = "redis"
    replicas     = 1

    selector {
      match_labels = {
        app = "redis"
      }
    }

    template {
      metadata {
        labels = {
          app = "redis"
        }
      }

      spec {
        container {
          name  = "redis"
          image = "redis:7-alpine"

          port {
            container_port = 6379
            name           = "redis"
          }

          command = [
            "redis-server",
            "--requirepass",
            "$(REDIS_PASSWORD)",
            "--appendonly",
            "yes",
            "--maxmemory",
            "512mb",
            "--maxmemory-policy",
            "allkeys-lru"
          ]

          env {
            name = "REDIS_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.database_credentials.metadata[0].name
                key  = "redis-password"
              }
            }
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "1Gi"
            }
          }

          volume_mount {
            name       = "redis-storage"
            mount_path = "/data"
          }

          liveness_probe {
            exec {
              command = ["redis-cli", "ping"]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            exec {
              command = ["redis-cli", "ping"]
            }
            initial_delay_seconds = 5
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 3
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "redis-storage"
      }

      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = "do-block-storage"

        resources {
          requests = {
            storage = var.redis_storage_size
          }
        }
      }
    }
  }
}

# Redis Service
resource "kubernetes_service" "redis" {
  metadata {
    name      = "redis"
    namespace = kubernetes_namespace.tfvisualizer.metadata[0].name
    labels = {
      app = "redis"
    }
  }

  spec {
    selector = {
      app = "redis"
    }

    port {
      name        = "redis"
      port        = 6379
      target_port = 6379
      protocol    = "TCP"
    }

    type       = "ClusterIP"
    cluster_ip = "None" # Headless service for StatefulSet
  }
}

# Database credentials secret
resource "kubernetes_secret" "database_credentials" {
  metadata {
    name      = "database-credentials"
    namespace = kubernetes_namespace.tfvisualizer.metadata[0].name
  }

  data = {
    postgres-password = var.postgres_password
    redis-password    = var.redis_password
  }

  type = "Opaque"
}
