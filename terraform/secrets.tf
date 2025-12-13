# Namespace for Sealed Secrets Controller
resource "kubernetes_namespace" "secrets" {
  metadata {
    name = "secrets"
  }
}

# Sealed Secrets Controller
# This controller watches for SealedSecret resources and decrypts them into regular Secrets
resource "helm_release" "sealed_secrets" {
  name       = "sealed-secrets"
  repository = "https://bitnami-labs.github.io/sealed-secrets"
  chart      = "sealed-secrets"
  namespace  = kubernetes_namespace.secrets.metadata[0].name

  # Wait for the controller to be ready before continuing
  wait          = true
  wait_for_jobs = true
  timeout       = 300

  # Handle existing releases
  replace       = true
  force_update  = true
  recreate_pods = false

  set {
    name  = "fullnameOverride"
    value = "sealed-secrets"
  }

  set {
    name  = "commandArgs[0]"
    value = "--update-status"
  }

  # Enable metrics for monitoring
  set {
    name  = "metrics.serviceMonitor.enabled"
    value = "false" # Set to true if using Prometheus Operator
  }
}

# Output the sealed-secrets public certificate
# This can be used to seal secrets outside of the cluster
output "sealed_secrets_cert_command" {
  description = "Command to fetch the sealed-secrets public certificate"
  value       = "kubeseal --fetch-cert --controller-name=sealed-secrets --controller-namespace=secrets"
}

# Note: The actual SealedSecret resource is created and managed by GitHub Actions
# See .github/workflows/terraform.yml and scripts/create-sealed-secret.sh
#
# The SealedSecret will be automatically converted to a regular Secret named
# "tfvisualizer-config" in the "tfvisualizer" namespace by the sealed-secrets controller
