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

