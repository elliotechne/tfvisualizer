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