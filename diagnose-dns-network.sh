#!/bin/bash

echo "============================================"
echo "DNS Network Issue Diagnosis"
echo "============================================"
echo ""

echo "1. Check kube-dns service:"
echo "-------------------------------------------"
kubectl get svc kube-dns -n kube-system -o yaml
echo ""

echo "2. Check service endpoints:"
echo "-------------------------------------------"
kubectl get endpoints kube-dns -n kube-system
echo ""

echo "3. Check CoreDNS pod IP:"
echo "-------------------------------------------"
kubectl get pods -n kube-system -l k8s-app=coredns -o wide
echo ""

echo "4. Check if service selector matches pod labels:"
echo "-------------------------------------------"
echo "Service selector:"
kubectl get svc kube-dns -n kube-system -o jsonpath='{.spec.selector}' | jq
echo ""
echo "CoreDNS pod labels:"
kubectl get pods -n kube-system -l k8s-app=coredns -o jsonpath='{.items[0].metadata.labels}' | jq
echo ""

echo "5. Check network policies blocking DNS:"
echo "-------------------------------------------"
kubectl get networkpolicies -A
echo ""

echo "6. From app pod - check resolv.conf:"
echo "-------------------------------------------"
APP_POD=$(kubectl get pods -n tfvisualizer -l app=tfvisualizer -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$APP_POD" ]; then
    kubectl exec $APP_POD -n tfvisualizer -- cat /etc/resolv.conf
    echo ""

    echo "7. From app pod - test TCP to DNS service:"
    echo "-------------------------------------------"
    DNS_IP=$(kubectl get svc kube-dns -n kube-system -o jsonpath='{.spec.clusterIP}')
    echo "DNS Service IP: $DNS_IP"
    kubectl exec $APP_POD -n tfvisualizer -- timeout 5 nc -zv $DNS_IP 53 2>&1
    echo ""

    echo "8. From app pod - test TCP to CoreDNS pod directly:"
    echo "-------------------------------------------"
    COREDNS_POD_IP=$(kubectl get pods -n kube-system -l k8s-app=coredns -o jsonpath='{.items[0].status.podIP}')
    echo "CoreDNS Pod IP: $COREDNS_POD_IP"
    kubectl exec $APP_POD -n tfvisualizer -- timeout 5 nc -zv $COREDNS_POD_IP 53 2>&1
    echo ""

    echo "9. From app pod - test ICMP to DNS:"
    echo "-------------------------------------------"
    kubectl exec $APP_POD -n tfvisualizer -- ping -c 2 $DNS_IP 2>&1 || echo "Ping not available or failed"
fi

echo ""
echo "10. Check CNI plugin (Cilium for DO):"
echo "-------------------------------------------"
kubectl get pods -n kube-system | grep cilium
echo ""

echo "11. Check cluster nodes:"
echo "-------------------------------------------"
kubectl get nodes -o wide
echo ""

echo "============================================"
echo "Diagnosis Complete"
echo "============================================"
