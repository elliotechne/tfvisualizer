resource "kubernetes_namespace" "secrets" {
  metadata {
    name = "secrets"
  }
}

resource "helm_release" "secrets" {
  name       = "sealed-secrets"
  repository = "https://bitnami-labs.github.io/sealed-secrets"
  chart      = "sealed-secrets"
  namespace  = "secrets"
  wait       = "false"
}
