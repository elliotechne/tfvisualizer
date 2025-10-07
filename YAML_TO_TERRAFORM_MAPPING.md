# YAML to Terraform Mapping Guide

Complete mapping of Kubernetes YAML files to Terraform resources.

---

## 📋 Overview

All Kubernetes resources have been converted from YAML manifests to Terraform code for better infrastructure management.

| YAML File | Terraform File | Resources |
|-----------|----------------|-----------|
| `k8s/namespace.yaml` | `terraform/kubernetes.tf` | Namespace |
| `k8s/postgres.yaml` | `terraform/databases.tf` | PostgreSQL StatefulSet, Service, Secret |
| `k8s/redis.yaml` | `terraform/databases.tf` | Redis StatefulSet, Service |
| `k8s/deployment.yaml` | `terraform/kubernetes.tf` | Deployment, Service, HPA, PDB |
| `k8s/secrets.yaml.example` | `terraform/kubernetes.tf` | Secrets, ConfigMaps |

---

## 🔄 Detailed Mappings

### 1. Namespace (namespace.yaml → kubernetes.tf)

**YAML:**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tfvisualizer
  labels:
    name: tfvisualizer
    environment: production
```

**Terraform:**
```hcl
resource "kubernetes_namespace" "tfvisualizer" {
  metadata {
    name = var.project_name
    labels = {
      name        = var.project_name
      environment = var.environment
    }
  }
}
```

**Location:** `terraform/kubernetes.tf:31-40`

---

### 2. PostgreSQL (postgres.yaml → databases.tf)

#### StatefulSet

**YAML:**
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: tfvisualizer
spec:
  serviceName: postgres
  replicas: 1
  template:
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        # ... (rest of spec)
```

**Terraform:**
```hcl
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
          # ... (rest of spec)
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
```

**Location:** `terraform/databases.tf:2-120`

#### Service

**YAML:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: tfvisualizer
spec:
  ports:
  - port: 5432
    name: postgres
  clusterIP: None
  selector:
    app: postgres
```

**Terraform:**
```hcl
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
    cluster_ip = "None"  # Headless service
  }
}
```

**Location:** `terraform/databases.tf:122-147`

---

### 3. Redis (redis.yaml → databases.tf)

#### StatefulSet

**YAML:**
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
  namespace: tfvisualizer
spec:
  serviceName: redis
  replicas: 1
  template:
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        command:
        - redis-server
        - --requirepass
        - $(REDIS_PASSWORD)
        # ... (rest of spec)
```

**Terraform:**
```hcl
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
          # ... (rest of spec)
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
```

**Location:** `terraform/databases.tf:149-264`

#### Service

**YAML:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: tfvisualizer
spec:
  ports:
  - port: 6379
    name: redis
  clusterIP: None
  selector:
    app: redis
```

**Terraform:**
```hcl
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
    cluster_ip = "None"  # Headless service
  }
}
```

**Location:** `terraform/databases.tf:266-291`

---

### 4. Application Deployment (deployment.yaml → kubernetes.tf)

#### Deployment

**YAML:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tfvisualizer-app
  namespace: tfvisualizer
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    spec:
      containers:
      - name: tfvisualizer
        image: ghcr.io/elliotechne/tfvisualizer:latest
        # ... (rest of spec)
```

**Terraform:**
```hcl
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
          name  = "tfvisualizer"
          image = "${var.docker_registry}/${var.docker_image}:${var.docker_tag}"

          port {
            container_port = 80
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
              port = 80
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 3
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 80
            }
            initial_delay_seconds = 10
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 3
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
        max_unavailable = "0"
      }
    }
  }
}
```

**Location:** `terraform/kubernetes.tf:90-188`

#### Service (LoadBalancer)

**YAML:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: tfvisualizer-service
  namespace: tfvisualizer
  annotations:
    service.beta.kubernetes.io/do-loadbalancer-name: "tfvisualizer-production-lb"
    service.beta.kubernetes.io/do-loadbalancer-redirect-http-to-https: "true"
spec:
  type: LoadBalancer
  selector:
    app: tfvisualizer
  ports:
  - name: http
    port: 80
    targetPort: 80
  - name: https
    port: 443
    targetPort: 80
```

**Terraform:**
```hcl
resource "kubernetes_service" "app" {
  metadata {
    name      = "tfvisualizer-service"
    namespace = kubernetes_namespace.tfvisualizer.metadata[0].name
    annotations = {
      "service.beta.kubernetes.io/do-loadbalancer-name"                              = "${var.project_name}-${var.environment}-lb"
      "service.beta.kubernetes.io/do-loadbalancer-protocol"                          = "http"
      "service.beta.kubernetes.io/do-loadbalancer-healthcheck-path"                  = "/health"
      "service.beta.kubernetes.io/do-loadbalancer-healthcheck-protocol"              = "http"
      "service.beta.kubernetes.io/do-loadbalancer-certificate-id"                    = digitalocean_certificate.cert.id
      "service.beta.kubernetes.io/do-loadbalancer-redirect-http-to-https"            = "true"
      "service.beta.kubernetes.io/do-loadbalancer-enable-proxy-protocol"             = "true"
    }
  }

  spec {
    selector = {
      app = "tfvisualizer"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }

    port {
      name        = "https"
      port        = 443
      target_port = 80
      protocol    = "TCP"
    }

    type = "LoadBalancer"
  }
}
```

**Location:** `terraform/kubernetes.tf:190-227`

#### HorizontalPodAutoscaler

**YAML:**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: tfvisualizer-hpa
  namespace: tfvisualizer
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: tfvisualizer-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

**Terraform:**
```hcl
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
```

**Location:** `terraform/kubernetes.tf:229-268`

#### PodDisruptionBudget

**YAML:**
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: tfvisualizer-pdb
  namespace: tfvisualizer
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app: tfvisualizer
```

**Terraform:**
```hcl
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
```

**Location:** `terraform/kubernetes.tf:293-308`

---

### 5. Secrets & ConfigMaps (secrets.yaml.example → kubernetes.tf)

#### Database Credentials Secret

**YAML:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: database-credentials
  namespace: tfvisualizer
type: Opaque
stringData:
  postgres-password: "secure-postgres-password"
  redis-password: "secure-redis-password"
```

**Terraform:**
```hcl
resource "kubernetes_secret" "database_credentials" {
  metadata {
    name      = "database-credentials"
    namespace = kubernetes_namespace.tfvisualizer.metadata[0].name
  }

  data = {
    postgres-password = base64encode(var.postgres_password)
    redis-password    = base64encode(var.redis_password)
  }

  type = "Opaque"
}
```

**Location:** `terraform/databases.tf:293-305`

#### Application Config Secret

**YAML:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: tfvisualizer-config
  namespace: tfvisualizer
type: Opaque
stringData:
  FLASK_ENV: "production"
  SECRET_KEY: "your-secret-key"
  DATABASE_URL: "postgresql://..."
  # ... (rest of secrets)
```

**Terraform:**
```hcl
resource "kubernetes_secret" "app_config" {
  metadata {
    name      = "tfvisualizer-config"
    namespace = kubernetes_namespace.tfvisualizer.metadata[0].name
  }

  data = {
    FLASK_ENV                 = var.environment
    PORT                      = "80"
    SECRET_KEY                = var.secret_key
    JWT_SECRET                = var.jwt_secret
    DATABASE_URL              = "postgresql://tfuser:${var.postgres_password}@postgres.${kubernetes_namespace.tfvisualizer.metadata[0].name}.svc.cluster.local:5432/tfvisualizer"
    DB_HOST                   = "postgres.${kubernetes_namespace.tfvisualizer.metadata[0].name}.svc.cluster.local"
    DB_PORT                   = "5432"
    DB_NAME                   = "tfvisualizer"
    DB_USER                   = "tfuser"
    DB_PASSWORD               = var.postgres_password
    REDIS_URL                 = "redis://:${var.redis_password}@redis.${kubernetes_namespace.tfvisualizer.metadata[0].name}.svc.cluster.local:6379"
    REDIS_HOST                = "redis.${kubernetes_namespace.tfvisualizer.metadata[0].name}.svc.cluster.local"
    REDIS_PORT                = "6379"
    REDIS_PASSWORD            = var.redis_password
    STRIPE_SECRET_KEY         = var.stripe_secret_key
    STRIPE_PUBLISHABLE_KEY    = var.stripe_publishable_key
    STRIPE_WEBHOOK_SECRET     = var.stripe_webhook_secret
    STRIPE_PRICE_ID_PRO       = var.stripe_price_id_pro
    S3_BUCKET_NAME            = digitalocean_spaces_bucket.files.name
    AWS_ACCESS_KEY_ID         = var.spaces_access_key
    AWS_SECRET_ACCESS_KEY     = var.spaces_secret_key
    AWS_REGION                = var.region
  }

  type = "Opaque"
}
```

**Location:** `terraform/kubernetes.tf:42-75`

#### Application ConfigMap

**YAML:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: tfvisualizer-config
  namespace: tfvisualizer
data:
  CORS_ORIGINS: "https://tfvisualizer.com"
  LOG_LEVEL: "INFO"
```

**Terraform:**
```hcl
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
```

**Location:** `terraform/kubernetes.tf:77-88`

#### Docker Registry Secret

**YAML:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: docker-registry-credentials
  namespace: tfvisualizer
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: BASE64_ENCODED_CONFIG
```

**Terraform:**
```hcl
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
```

**Location:** `terraform/kubernetes.tf:270-291`

---

## 🎯 Key Differences

### Variable References

**YAML:** Static values
```yaml
replicas: 2
```

**Terraform:** Variable references
```hcl
replicas = var.app_replicas
```

### Resource Dependencies

**YAML:** Manual ordering required
```bash
kubectl apply -f namespace.yaml
kubectl apply -f postgres.yaml
kubectl apply -f deployment.yaml
```

**Terraform:** Automatic dependency resolution
```hcl
namespace = kubernetes_namespace.tfvisualizer.metadata[0].name
```

### Secret Encoding

**YAML:** Manual base64 encoding
```yaml
data:
  password: c2VjcmV0  # pre-encoded
```

**Terraform:** Automatic encoding
```hcl
data = {
  password = base64encode(var.password)
}
```

### Dynamic Values

**YAML:** Static strings
```yaml
image: ghcr.io/elliotechne/tfvisualizer:latest
```

**Terraform:** Interpolated variables
```hcl
image = "${var.docker_registry}/${var.docker_image}:${var.docker_tag}"
```

---

## 📊 Benefits of Terraform

| Feature | YAML | Terraform |
|---------|------|-----------|
| Variables | ❌ | ✅ |
| State tracking | ❌ | ✅ |
| Dependency management | Manual | Automatic |
| Drift detection | ❌ | ✅ |
| Plan/preview | ❌ | ✅ |
| Rollback | Manual | Automatic |
| Documentation | Manual | Generated |
| CI/CD integration | Manual | Native |

---

## 🔄 Converting YAML to Terraform

If you need to add new Kubernetes resources:

1. **Create YAML first** (easier to prototype)
2. **Test with kubectl**
3. **Convert to Terraform:**

```bash
# Example conversion
kubectl get deployment tfvisualizer-app -n tfvisualizer -o yaml > deployment.yaml

# Manually convert to Terraform syntax
# Reference: https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs
```

4. **Add to appropriate Terraform file:**
   - Application resources → `kubernetes.tf`
   - Database resources → `databases.tf`
   - Infrastructure → `main.tf`

5. **Import existing resources** (if already deployed):
```bash
terraform import kubernetes_deployment.app tfvisualizer/tfvisualizer-app
```

---

## 📚 Additional Resources

- [Terraform Kubernetes Provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)
- [Kubernetes API Reference](https://kubernetes.io/docs/reference/kubernetes-api/)
- [Terraform Import Guide](https://www.terraform.io/docs/cli/import/index.html)

---

**All Kubernetes resources are managed by Terraform. YAML files are for reference only.**
