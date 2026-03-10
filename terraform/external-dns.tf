# Secret for external-dns DigitalOcean token
resource "kubernetes_secret" "external_dns_token" {
  metadata {
    name      = "external-dns-token"
    namespace = "external-dns"
  }

  data = {
    DO_TOKEN = var.do_token
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
    value = "DO_TOKEN"
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
    name  = "args[0]"
    value = "--log-level=info"
  }

  set {
    name  = "args[1]"
    value = "--log-format=json"
  }

  set {
    name  = "args[2]"
    value = "--interval=1m"
  }

  set {
    name  = "args[3]"
    value = "--source=istio-gateway"
  }

  set {
    name  = "args[4]"
    value = "--source=service"
  }

  set {
    name  = "args[5]"
    value = "--policy=sync"
  }

  set {
    name  = "args[6]"
    value = "--registry=txt"
  }

  set {
    name  = "args[7]"
    value = "--managed-record-types=A"
  }

  set {
    name  = "args[8]"
    value = "--managed-record-types=AAAA"
  }

  set {
    name  = "args[9]"
    value = "--managed-record-types=CNAME"
  }

  set {
    name  = "args[10]"
    value = "--managed-record-types=TXT"
  }

  set {
    name  = "args[11]"
    value = "--txt-owner-id=${var.project_name}-${var.environment}"
  }

  set {
    name  = "args[12]"
    value = "--txt-prefix=external-dns-"
  }

  set {
    name  = "args[13]"
    value = "--domain-filter=${var.domain_name}"
  }

  set {
    name  = "args[14]"
    value = "--provider=digitalocean"
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
