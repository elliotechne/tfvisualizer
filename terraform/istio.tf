resource "kubernetes_namespace" "istio-system" {
  metadata {
    name = "istio-system"
  }
}

resource "helm_release" "istio-base" {
  name       = "base"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "base"
  namespace  = "istio-system"
  version    = "1.27.3"
  wait       = "false"
}

resource "helm_release" "istiod" {
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  namespace  = "istio-system"
  version    = "1.27.3"
  wait       = "false"

  depends_on = [helm_release.istio-base]
}

# Istio Ingress Gateway — exposes a LoadBalancer for inbound traffic
resource "helm_release" "istio_ingressgateway" {
  name       = "istio-ingressgateway"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "gateway"
  namespace  = "istio-system"
  version    = "1.27.3"
  wait       = false

  # Use values instead of set blocks to avoid Helm's dot/comma parsing issues with annotation keys and multi-value strings
  values = [
    yamlencode({
      service = {
        type = "LoadBalancer"
        annotations = {
          "service.beta.kubernetes.io/do-loadbalancer-name" = "${var.project_name}-${var.environment}-istio-lb"
          "external-dns.alpha.kubernetes.io/hostname"       = "${var.domain_name},www.${var.domain_name}"
        }
      }
    })
  ]

  depends_on = [helm_release.istiod]
}