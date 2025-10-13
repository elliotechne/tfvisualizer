#!/bin/bash

NAMESPACE="tfvisualizer"

echo "============================================"
echo "Testing DNS Connectivity"
echo "============================================"
echo ""

echo "1. CoreDNS pod status:"
echo "-------------------------------------------"
kubectl get pods -n kube-system -l k8s-app=coredns -o wide
echo ""

echo "2. CoreDNS service:"
echo "-------------------------------------------"
kubectl get svc kube-dns -n kube-system
echo ""

echo "3. CoreDNS service endpoints:"
echo "-------------------------------------------"
kubectl get endpoints kube-dns -n kube-system
echo ""

echo "4. Get DNS service IP:"
echo "-------------------------------------------"
DNS_IP=$(kubectl get svc kube-dns -n kube-system -o jsonpath='{.spec.clusterIP}')
echo "DNS Service IP: $DNS_IP"
echo ""

echo "5. Check /etc/resolv.conf in app pod:"
echo "-------------------------------------------"
APP_POD=$(kubectl get pods -n $NAMESPACE -l app=tfvisualizer -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$APP_POD" ]; then
    echo "App pod: $APP_POD"
    kubectl exec $APP_POD -n $NAMESPACE -- cat /etc/resolv.conf
    echo ""

    echo "6. Test if app pod can reach DNS service IP:"
    echo "-------------------------------------------"
    echo "Testing connection to $DNS_IP:53..."
    kubectl exec $APP_POD -n $NAMESPACE -- nc -zv -w 2 $DNS_IP 53 2>&1 || echo "❌ Cannot reach DNS service"
    echo ""

    echo "7. Try DNS lookup again (wait for DNS to be ready):"
    echo "-------------------------------------------"
    echo "Waiting 5 seconds for DNS to stabilize..."
    sleep 5
    echo "Testing kubernetes.default lookup..."
    kubectl exec $APP_POD -n $NAMESPACE -- nslookup kubernetes.default 2>&1
    echo ""

    echo "8. Test postgres service lookup:"
    echo "-------------------------------------------"
    kubectl exec $APP_POD -n $NAMESPACE -- nslookup postgres 2>&1
    echo ""

    echo "9. Direct dig query to DNS:"
    echo "-------------------------------------------"
    kubectl exec $APP_POD -n $NAMESPACE -- nslookup postgres.tfvisualizer.svc.cluster.local $DNS_IP 2>&1
else
    echo "❌ No app pod found"
fi

echo ""
echo "10. CoreDNS logs:"
echo "-------------------------------------------"
COREDNS_POD=$(kubectl get pods -n kube-system -l k8s-app=coredns -o jsonpath='{.items[0].metadata.name}')
echo "CoreDNS pod: $COREDNS_POD"
kubectl logs $COREDNS_POD -n kube-system --tail=20
echo ""

echo "============================================"
echo "Test Complete"
echo "============================================"
