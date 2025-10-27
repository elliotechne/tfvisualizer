resource "helm_release" "goldilocks" {
  name             = "goldilocks"
  repository       = "https://charts.fairwinds.com/stable"
  chart            = "goldilocks"
  namespace        = "fairwinds-stable"
  version          = "10.1.0"
  create_namespace = true
}

resource "helm_release" "vpa" {
  name             = "vpa"
  repository       = "https://charts.fairwinds.com/stable"
  chart            = "vpa"
  namespace        = "fairwinds-stable"
  version          = "4.9.0"
  create_namespace = true
}

resource "helm_release" "metrics-server" {
  name             = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  namespace        = "metrics-server"
  version          = "3.13.0"
  create_namespace = true
}
