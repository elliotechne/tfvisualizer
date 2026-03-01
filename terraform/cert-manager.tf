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

# Secret containing the ZeroSSL EAB HMAC key
resource "kubernetes_secret" "zerossl_eab" {
  metadata {
    name      = "zerossl-eab-secret"
    namespace = "cert-manager"
  }

  data = {
    secret = var.zerossl_eab_hmac_key
  }

  depends_on = [helm_release.cert_manager]
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

# ZeroSSL Production ClusterIssuer using DNS01 via DigitalOcean
resource "kubectl_manifest" "zerossl_cluster_issuer" {
  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: zerossl-prod
    spec:
      acme:
        server: https://acme.zerossl.com/v2/DV90
        email: ${var.letsencrypt_email}
        privateKeySecretRef:
          name: zerossl-prod-account-key
        externalAccountBinding:
          keyID: ${var.zerossl_eab_kid}
          keySecretRef:
            name: zerossl-eab-secret
            key: secret
        solvers:
        - dns01:
            digitalocean:
              tokenSecretRef:
                name: digitalocean-dns
                key: access-token
  YAML

  depends_on = [
    time_sleep.wait_for_cert_manager,
    kubernetes_secret.zerossl_eab,
    kubernetes_secret.do_dns_cert_manager,
  ]
}
