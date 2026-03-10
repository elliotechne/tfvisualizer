# Cert-manager for SSL certificate management
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = "cert-manager"
  version    = "v1.14.4"

  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "global.leaderElection.namespace"
    value = "cert-manager"
  }
}

# Wait for cert-manager to be ready before creating ClusterIssuer
resource "time_sleep" "wait_for_cert_manager" {
  depends_on = [helm_release.cert_manager]

  create_duration = "60s"
}

# DigitalOcean API token secret for cert-manager DNS01 solver
resource "kubernetes_secret" "do_dns_cert_manager" {
  metadata {
    name      = "digitalocean-dns"
    namespace = "cert-manager"
  }

  data = {
    access-token = var.do_token
  }

  depends_on = [helm_release.cert_manager]
}

# Let's Encrypt Production ClusterIssuer using DNS01 via DigitalOcean
resource "kubectl_manifest" "letsencrypt_cluster_issuer" {
  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-prod
    spec:
      acme:
        server: https://acme-v02.api.letsencrypt.org/directory
        email: ${var.letsencrypt_email}
        privateKeySecretRef:
          name: letsencrypt-prod-account-key
        solvers:
        - dns01:
            digitalocean:
              tokenSecretRef:
                name: digitalocean-dns
                key: access-token
  YAML

  depends_on = [
    time_sleep.wait_for_cert_manager,
    kubernetes_secret.do_dns_cert_manager,
  ]
}
