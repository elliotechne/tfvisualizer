# TLS Certificate for main domain (in istio-system so ingressgateway can access it)
resource "kubectl_manifest" "tfvisualizer_cert" {
  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: Certificate
    metadata:
      name: tfvisualizer-tls
      namespace: istio-system
    spec:
      secretName: tfvisualizer-tls
      issuerRef:
        name: letsencrypt-prod
        kind: ClusterIssuer
      dnsNames:
      - ${var.domain_name}
  YAML

  depends_on = [kubectl_manifest.letsencrypt_cluster_issuer]
}

# TLS Certificate for www subdomain (in istio-system so ingressgateway can access it)
resource "kubectl_manifest" "tfvisualizer_www_cert" {
  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: Certificate
    metadata:
      name: tfvisualizer-www-tls
      namespace: istio-system
    spec:
      secretName: tfvisualizer-www-tls
      issuerRef:
        name: letsencrypt-prod
        kind: ClusterIssuer
      dnsNames:
      - www.${var.domain_name}
  YAML

  depends_on = [kubectl_manifest.letsencrypt_cluster_issuer]
}

# Istio Gateway — terminates TLS for main and www domains
# Placed in istio-system so it is always visible to istiod regardless of
# PILOT_SCOPE_GATEWAY_TO_NAMESPACE. Selector uses app: istio-ingressgateway
# which is set from the Helm release name and is guaranteed on every pod.
resource "kubectl_manifest" "istio_gateway" {
  yaml_body = <<-YAML
    apiVersion: networking.istio.io/v1beta1
    kind: Gateway
    metadata:
      name: tfvisualizer-gateway
      namespace: istio-system
    spec:
      selector:
        app: istio-ingressgateway
      servers:
      - port:
          number: 80
          name: http
          protocol: HTTP
        hosts:
        - ${var.domain_name}
        - www.${var.domain_name}
        tls:
          httpsRedirect: true
      - port:
          number: 443
          name: https-main
          protocol: HTTPS
        hosts:
        - ${var.domain_name}
        tls:
          mode: SIMPLE
          credentialName: tfvisualizer-tls
      - port:
          number: 443
          name: https-www
          protocol: HTTPS
        hosts:
        - www.${var.domain_name}
        tls:
          mode: SIMPLE
          credentialName: tfvisualizer-www-tls
  YAML

  depends_on = [
    helm_release.istio_ingressgateway,
    kubectl_manifest.tfvisualizer_cert,
    kubectl_manifest.tfvisualizer_www_cert,
  ]
}

# VirtualService — routes main domain traffic to the app service
resource "kubectl_manifest" "istio_virtual_service" {
  yaml_body = <<-YAML
    apiVersion: networking.istio.io/v1beta1
    kind: VirtualService
    metadata:
      name: tfvisualizer-vs
      namespace: ${kubernetes_namespace.tfvisualizer.metadata[0].name}
    spec:
      hosts:
      - ${var.domain_name}
      gateways:
      - istio-system/tfvisualizer-gateway
      http:
      - match:
        - uri:
            prefix: /
        route:
        - destination:
            host: ${kubernetes_service.app.metadata[0].name}.${kubernetes_namespace.tfvisualizer.metadata[0].name}.svc.cluster.local
            port:
              number: 80
        timeout: 60s
  YAML

  depends_on = [kubectl_manifest.istio_gateway]
}

# VirtualService — permanent redirect from www to root domain
resource "kubectl_manifest" "istio_www_redirect_vs" {
  yaml_body = <<-YAML
    apiVersion: networking.istio.io/v1beta1
    kind: VirtualService
    metadata:
      name: tfvisualizer-www-redirect
      namespace: ${kubernetes_namespace.tfvisualizer.metadata[0].name}
    spec:
      hosts:
      - www.${var.domain_name}
      gateways:
      - istio-system/tfvisualizer-gateway
      http:
      - match:
        - uri:
            prefix: /
        redirect:
          authority: ${var.domain_name}
          redirectCode: 301
  YAML

  depends_on = [kubectl_manifest.istio_gateway]
}
