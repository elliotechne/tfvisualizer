resource "kubernetes_namespace" "kube_namespace" {
  metadata {
    name     = "istio-system"
  }
}

resource "helm_release" "istio-base" {
  name       = "istio"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istio-base"
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
}