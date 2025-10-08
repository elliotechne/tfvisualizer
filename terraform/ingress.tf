# Ingress resource for TFVisualizer
resource "kubernetes_ingress_v1" "app" {
  metadata {
    name      = "tfvisualizer-ingress"
    namespace = kubernetes_namespace.tfvisualizer.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer"                   = "zerossl-prod"
      "nginx.ingress.kubernetes.io/ssl-redirect"         = "true"
      "nginx.ingress.kubernetes.io/force-ssl-redirect"   = "true"
      "nginx.ingress.kubernetes.io/proxy-body-size"      = "50m"
      "nginx.ingress.kubernetes.io/proxy-connect-timeout" = "60"
      "nginx.ingress.kubernetes.io/proxy-send-timeout"   = "60"
      "nginx.ingress.kubernetes.io/proxy-read-timeout"   = "60"
    }
  }

  spec {
    ingress_class_name = "nginx"

    tls {
      hosts = [
        var.domain_name,
        "www.${var.domain_name}"
      ]
      secret_name = "tfvisualizer-tls"
    }

    rule {
      host = var.domain_name
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.app.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }

    rule {
      host = "www.${var.domain_name}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.app.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.nginx_ingress,
    kubernetes_manifest.zerossl_cluster_issuer
  ]
}
