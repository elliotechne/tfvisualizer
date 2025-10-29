resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace  = "monitoring"
  version    = "6.29.1"
  wait       = "false"

  # RBAC Configuration
  set {
    name  = "rbac.create"
    value = "true"
  }
  
  set {
    name  = "rbac.pspEnabled"
    value = "false"
  }

  # Service Account
  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "grafana"
  }

  # Service Configuration
  set {
    name  = "service.type"
    value = "ClusterIP"
  }

  set {
    name  = "service.port"
    value = "80"
  }

  set {
    name  = "service.targetPort"
    value = "3000"
  }

  # Ingress Configuration
  set {
    name  = "ingress.enabled"
    value = "true"
  }

  set {
    name  = "ingress.annotations.kubernetes\\.io/ingress\\.class"
    value = "nginx"
  }

  set {
    name  = "ingress.annotations.cert-manager\\.io/cluster-issuer"
    value = "letsencrypt-prod"
  }

  # Persistence Configuration
  set {
    name  = "persistence.enabled"
    value = "true"
  }

  set {
    name  = "persistence.storageClassName"
    value = "do-block-storage"
  }

  set {
    name  = "persistence.size"
    value = "10Gi"
  }

  # Security Context
  set {
    name  = "securityContext.runAsUser"
    value = "472"
  }

  set {
    name  = "securityContext.runAsGroup"
    value = "472"
  }

  set {
    name  = "securityContext.fsGroup"
    value = "472"
  }

  # Pod Security Context
  set {
    name  = "podSecurityContext.runAsNonRoot"
    value = "true"
  }

  set {
    name  = "podSecurityContext.seccompProfile.type"
    value = "RuntimeDefault"
  }

  # Resources
  set {
    name  = "resources.limits.cpu"
    value = "1000m"
  }

  set {
    name  = "resources.limits.memory"
    value = "1Gi"
  }

  set {
    name  = "resources.requests.cpu"
    value = "500m"
  }

  set {
    name  = "resources.requests.memory"
    value = "512Mi"
  }

  # Datasources Configuration
  set {
    name  = "datasources.datasources\\.yaml.apiVersion"
    value = "1"
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[0].name"
    value = "Prometheus"
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[0].type"
    value = "prometheus"
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[0].url"
    value = "http://prometheus-server.monitoring.svc.cluster.local"
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[0].access"
    value = "proxy"
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[0].isDefault"
    value = "true"
  }

  # Dashboard Configuration
  set {
    name  = "dashboardProviders.dashboardproviders\\.yaml.apiVersion"
    value = "1"
  }

  set {
    name  = "dashboardProviders.dashboardproviders\\.yaml.providers[0].name"
    value = "default"
  }

  set {
    name  = "dashboardProviders.dashboardproviders\\.yaml.providers[0].orgId"
    value = "1"
  }

  set {
    name  = "dashboardProviders.dashboardproviders\\.yaml.providers[0].folder"
    value = ""
  }

  set {
    name  = "dashboardProviders.dashboardproviders\\.yaml.providers[0].type"
    value = "file"
  }

  set {
    name  = "dashboardProviders.dashboardproviders\\.yaml.providers[0].disableDeletion"
    value = "false"
  }

  set {
    name  = "dashboardProviders.dashboardproviders\\.yaml.providers[0].editable"
    value = "true"
  }

  set {
    name  = "dashboardProviders.dashboardproviders\\.yaml.providers[0].options.path"
    value = "/var/lib/grafana/dashboards/default"
  }

  # Pod Anti-Affinity
  set {
    name  = "affinity.podAntiAffinity.preferredDuringSchedulingIgnoredDuringExecution[0].weight"
    value = "100"
  }

  set {
    name  = "affinity.podAntiAffinity.preferredDuringSchedulingIgnoredDuringExecution[0].podAffinityTerm.labelSelector.matchExpressions[0].key"
    value = "app.kubernetes.io/name"
  }

  set {
    name  = "affinity.podAntiAffinity.preferredDuringSchedulingIgnoredDuringExecution[0].podAffinityTerm.labelSelector.matchExpressions[0].operator"
    value = "In"
  }

  set {
    name  = "affinity.podAntiAffinity.preferredDuringSchedulingIgnoredDuringExecution[0].podAffinityTerm.labelSelector.matchExpressions[0].values[0]"
    value = "grafana"
  }

  set {
    name  = "affinity.podAntiAffinity.preferredDuringSchedulingIgnoredDuringExecution[0].podAffinityTerm.topologyKey"
    value = "kubernetes.io/hostname"
  }
}

resource "kubernetes_config_map" "volumes-dashboard" {
  depends_on = [kubernetes_namespace.monitoring]
  metadata {
    name      = "volumes-dashboard-alerting"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "dashboard"
    }
  }
  data = {
    "dashboard.json" = "${file("${path.module}/grafana-dashboard/volume-alerting.json")}"
  }
}

# other dashboard

resource "kubernetes_config_map" "node" {
  depends_on = [kubernetes_namespace.monitoring]
  metadata {
    name      = "node"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "dashboard"
    }
  }
  data = {
    "node.json" = "${file("${path.module}/grafana-dashboard/node.json")}"
  }
}

resource "kubernetes_config_map" "coredns" {
  depends_on = [kubernetes_namespace.monitoring]
  metadata {
    name      = "coredns"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "dashboard"
    }
  }
  data = {
    "coredns.json" = "${file("${path.module}/grafana-dashboard/coredns.json")}"
  }
}

resource "kubernetes_config_map" "api" {
  depends_on = [kubernetes_namespace.monitoring]
  metadata {
    name      = "api"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "dashboard"
    }
  }
  data = {
    "api.json" = "${file("${path.module}/grafana-dashboard/api.json")}"
  }
}

resource "kubernetes_config_map" "kubelet" {
  depends_on = [kubernetes_namespace.monitoring]
  metadata {
    name      = "kubelet"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "dashboard"
    }
  }
  data = {
    "kubelet.json" = "${file("${path.module}/grafana-dashboard/kubelet.json")}"
  }
}

resource "kubernetes_config_map" "proxy" {
  depends_on = [kubernetes_namespace.monitoring]
  metadata {
    name      = "proxy"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "dashboard"
    }
  }
  data = {
    "proxy.json" = "${file("${path.module}/grafana-dashboard/proxy.json")}"
  }
}

resource "kubernetes_config_map" "statefulsets" {
  depends_on = [kubernetes_namespace.monitoring]
  metadata {
    name      = "statefulsets"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "dashboard"
    }
  }
  data = {
    "statefulsets.json" = "${file("${path.module}/grafana-dashboard/statefulsets.json")}"
  }
}

resource "kubernetes_config_map" "persistent-volumes" {
  depends_on = [kubernetes_namespace.monitoring]
  metadata {
    name      = "persistent-volumes"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "dashboard"
    }
  }
  data = {
    "persistent-volumes.json" = "${file("${path.module}/grafana-dashboard/persistent-volumes.json")}"
  }
}

resource "kubernetes_config_map" "prometheous-overview" {
  depends_on = [kubernetes_namespace.monitoring]
  metadata {
    name      = "prometheous-overview"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "dashboard"
    }
  }
  data = {
    "prometheous-overview.json" = "${file("${path.module}/grafana-dashboard/prometheous-overview.json")}"
  }
}

resource "kubernetes_config_map" "use-method-cluster" {
  depends_on = [kubernetes_namespace.monitoring]
  metadata {
    name      = "use-method-cluster"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "dashboard"
    }
  }
  data = {
    "use-method-cluster.json" = "${file("${path.module}/grafana-dashboard/use-method-cluster.json")}"
  }
}

resource "kubernetes_config_map" "use-method-node" {
  depends_on = [kubernetes_namespace.monitoring]
  metadata {
    name      = "use-method-node"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "dashboard"
    }
  }
  data = {
    "use-method-node.json" = "${file("${path.module}/grafana-dashboard/use-method-node.json")}"
  }
}

#compute resources dashboard
resource "kubernetes_config_map" "compute-resources-cluster" {
  depends_on = [kubernetes_namespace.monitoring]
  metadata {
    name      = "compute-resources-cluster"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "dashboard"
    }
  }
  data = {
    "compute-resources-cluster.json" = "${file("${path.module}/grafana-dashboard/compute-resources-cluster.json")}"
  }
}

resource "kubernetes_config_map" "compute-resources-node-pods" {
  depends_on = [kubernetes_namespace.monitoring]
  metadata {
    name      = "compute-resources-node-pods"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "dashboard"
    }
  }
  data = {
    "compute-resources-node-pods.json" = "${file("${path.module}/grafana-dashboard/compute-resources-node-pods.json")}"
  }
}

resource "kubernetes_config_map" "compute-resources-pod" {
  depends_on = [kubernetes_namespace.monitoring]
  metadata {
    name      = "compute-resources-pod"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "dashboard"
    }
  }
  data = {
    "compute-resources-pod.json" = "${file("${path.module}/grafana-dashboard/compute-resources-pod.json")}"
  }
}

resource "kubernetes_config_map" "compute-resources-workload" {
  depends_on = [kubernetes_namespace.monitoring]
  metadata {
    name      = "compute-resources-workload"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "dashboard"
    }
  }
  data = {
    "compute-resources-workload.json" = "${file("${path.module}/grafana-dashboard/compute-resources-workload.json")}"
  }
}

resource "kubernetes_config_map" "compute-resources-namespace-workloads" {
  depends_on = [kubernetes_namespace.monitoring]
  metadata {
    name      = "compute-resources-namespace-workloads"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "dashboard"
    }
  }
  data = {
    "compute-resources-namespace-workloads.json" = "${file("${path.module}/grafana-dashboard/compute-resources-namespace-workloads.json")}"
  }
}

resource "kubernetes_config_map" "computer-resources-namespace-pods" {
  depends_on = [kubernetes_namespace.monitoring]
  metadata {
    name      = "computer-resources-namespace-pods"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "dashboard"
    }
  }
  data = {
    "computer-resources-namespace-pods.json" = "${file("${path.module}/grafana-dashboard/computer-resources-namespace-pods.json")}"
  }
}

#networking dashboard
resource "kubernetes_config_map" "networking-namespace-pods" {
  depends_on = [kubernetes_namespace.monitoring]
  metadata {
    name      = "networking-namespace-pods"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "dashboard"
    }
  }
  data = {
    "networking-namespace-pods.json" = "${file("${path.module}/grafana-dashboard/networking-namespace-pods.json")}"
  }
}

resource "kubernetes_config_map" "networking-namespace-workload" {
  depends_on = [kubernetes_namespace.monitoring]
  metadata {
    name      = "networking-namespace-workload"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "dashboard"
    }
  }
  data = {
    "networking-namespace-workload.json" = "${file("${path.module}/grafana-dashboard/networking-namespace-workload.json")}"
  }
}

resource "kubernetes_config_map" "networking-cluster" {
  depends_on = [kubernetes_namespace.monitoring]
  metadata {
    name      = "networking-cluster"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "dashboard"
    }
  }
  data = {
    "networking-cluster.json" = "${file("${path.module}/grafana-dashboard/networking-cluster.json")}"
  }
}

resource "kubernetes_config_map" "networking-pods" {
  depends_on = [kubernetes_namespace.monitoring]
  metadata {
    name      = "networking-pods"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "dashboard"
    }
  }
  data = {
    "networking-pods.json" = "${file("${path.module}/grafana-dashboard/networking-pods.json")}"
  }
}

resource "kubernetes_config_map" "networking-workload" {
  depends_on = [kubernetes_namespace.monitoring]
  metadata {
    name      = "networking-workload"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "dashboard"
    }
  }
  data = {
    "networking-workload.json" = "${file("${path.module}/grafana-dashboard/networking-workload.json")}"
  }
}

#Istio dashboard
resource "kubernetes_config_map" "istio-control-plane" {
  depends_on = [kubernetes_namespace.monitoring]
  metadata {
    name      = "istio-control-plane"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "dashboard"
    }
  }
  data = {
    "istio-control-plane.json" = "${file("${path.module}/grafana-dashboard/istio-control-plane.json")}"
  }
}

resource "kubernetes_config_map" "istio-mesh" {
  depends_on = [kubernetes_namespace.monitoring]
  metadata {
    name      = "istio-mesh"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "dashboard"
    }
  }
  data = {
    "istio-mesh.json" = "${file("${path.module}/grafana-dashboard/istio-mesh.json")}"
  }
}

resource "kubernetes_config_map" "istio-performance" {
  depends_on = [kubernetes_namespace.monitoring]
  metadata {
    name      = "istio-performance"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "dashboard"
    }
  }
  data = {
    "istio-performance.json" = "${file("${path.module}/grafana-dashboard/istio-performance.json")}"
  }
}

resource "kubernetes_config_map" "istio-service" {
  depends_on = [kubernetes_namespace.monitoring]
  metadata {
    name      = "istio-service"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "dashboard"
    }
  }
  data = {
    "istio-service.json" = "${file("${path.module}/grafana-dashboard/istio-service.json")}"
  }
}

resource "kubernetes_config_map" "istio-workload" {
  depends_on = [kubernetes_namespace.monitoring]
  metadata {
    name      = "istio-workload"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "dashboard"
    }
  }
  data = {
    "istio-workload.json" = "${file("${path.module}/grafana-dashboard/istio-workload.json")}"
  }
}