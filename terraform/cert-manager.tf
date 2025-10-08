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
# Note: This must be applied AFTER cert-manager is installed
# Use kubectl apply or a separate terraform apply
resource "null_resource" "zerossl_cluster_issuer" {
  provisioner "local-exec" {
    command = <<-EOT
      cat <<EOF | kubectl apply -f -
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
      EOF
    EOT
  }

  depends_on = [
    helm_release.cert_manager,
    kubernetes_secret.zerossl_eab
  ]

  triggers = {
    email = var.letsencrypt_email
    kid   = var.zerossl_eab_kid
  }
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
