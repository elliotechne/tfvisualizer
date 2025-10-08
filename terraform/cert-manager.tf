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

# ZeroSSL ClusterIssuer
resource "kubernetes_manifest" "zerossl_cluster_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "zerossl-prod"
    }
    spec = {
      acme = {
        server = "https://acme.zerossl.com/v2/DV90"
        email  = var.letsencrypt_email
        privateKeySecretRef = {
          name = "zerossl-prod-account-key"
        }
        externalAccountBinding = {
          keyID = var.zerossl_eab_kid
          keySecretRef = {
            name = "zerossl-eab-secret"
            key  = "secret"
          }
          keyAlgorithm = "HS256"
        }
        solvers = [
          {
            http01 = {
              ingress = {
                class = "nginx"
              }
            }
          }
        ]
      }
    }
  }

  depends_on = [helm_release.cert_manager]
}

# ZeroSSL EAB secret
resource "kubernetes_secret" "zerossl_eab" {
  metadata {
    name      = "zerossl-eab-secret"
    namespace = "cert-manager"
  }

  data = {
    secret = var.zerossl_eab_hmac_key
  }

  type = "Opaque"

  depends_on = [helm_release.cert_manager]
}
