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

# ZeroSSL ClusterIssuer using kubectl provider
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
          keyAlgorithm: HS256
        solvers:
        - http01:
            ingress:
              class: nginx
  YAML

  depends_on = [
    time_sleep.wait_for_cert_manager,
    kubernetes_secret.zerossl_eab
  ]
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
