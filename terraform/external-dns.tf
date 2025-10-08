# Secret for external-dns DigitalOcean token
resource "kubernetes_secret" "external_dns_token" {
  metadata {
    name      = "external-dns-token"
    namespace = "external-dns"
  }

  data = {
    token = var.do_token
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.external_dns]
}

# Namespace for external-dns
resource "kubernetes_namespace" "external_dns" {
  metadata {
    name = "external-dns"
  }
}

# External DNS for automatic DNS management
resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = "external-dns"
  version    = "1.14.3"

  create_namespace = false

  set {
    name  = "provider"
    value = "digitalocean"
  }

  set {
    name  = "env[0].name"
    value = "DO_TOKEN"
  }

  set {
    name  = "env[0].valueFrom.secretKeyRef.name"
    value = kubernetes_secret.external_dns_token.metadata[0].name
  }

  set {
    name  = "env[0].valueFrom.secretKeyRef.key"
    value = "token"
  }

  set {
    name  = "interval"
    value = "1m"
  }

  set {
    name  = "policy"
    value = "sync"
  }

  set {
    name  = "sources[0]"
    value = "ingress"
  }

  set {
    name  = "sources[1]"
    value = "service"
  }

  set {
    name  = "domainFilters[0]"
    value = var.domain_name
  }

  set {
    name  = "txtOwnerId"
    value = "${var.project_name}-${var.environment}"
  }

  set {
    name  = "txtPrefix"
    value = "external-dns-"
  }

  set {
    name  = "logLevel"
    value = "info"
  }

  set {
    name  = "logFormat"
    value = "json"
  }

  depends_on = [kubernetes_secret.external_dns_token]
}
