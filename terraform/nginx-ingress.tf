# Nginx ingress controller removed — traffic is now handled by Istio ingressgateway.
# The istio-ingressgateway LoadBalancer service carries the
# external-dns.alpha.kubernetes.io/hostname annotation so external-dns will
# update DNS records to the Istio LB IP after this resource is destroyed.
