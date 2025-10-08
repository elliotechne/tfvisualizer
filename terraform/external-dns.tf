# External DNS for automatic DNS management
resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = "external-dns"
  version    = "1.14.3"

  create_namespace = true

  set {
    name  = "provider"
    value = "digitalocean"
  }

  set {
    name  = "digitalocean.apiToken"
    value = var.do_token
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
}
