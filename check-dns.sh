#!/bin/bash

echo "============================================"
echo "Kubernetes DNS Diagnostics"
echo "============================================"
echo ""

echo "1. Checking CoreDNS/kube-dns pods:"
echo "-------------------------------------------"
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
kubectl get pods -n kube-system -l k8s-app=coredns -o wide
echo ""

echo "2. Checking DNS service in kube-system:"
echo "-------------------------------------------"
kubectl get svc -n kube-system | grep -E "kube-dns|dns"
echo ""

echo "3. Checking DNS endpoints:"
echo "-------------------------------------------"
kubectl get endpoints kube-dns -n kube-system 2>&1 || echo "kube-dns endpoints not found"
echo ""

echo "4. CoreDNS/kube-dns logs:"
echo "-------------------------------------------"
DNS_POD=$(kubectl get pods -n kube-system -l k8s-app=kube-dns -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$DNS_POD" ]; then
    DNS_POD=$(kubectl get pods -n kube-system -l k8s-app=coredns -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
fi

if [ -n "$DNS_POD" ]; then
    echo "DNS Pod: $DNS_POD"
    kubectl logs $DNS_POD -n kube-system --tail=30
else
    echo "❌ No DNS pods found!"
fi
echo ""

echo "5. Checking /etc/resolv.conf from app pod:"
echo "-------------------------------------------"
APP_POD=$(kubectl get pods -n tfvisualizer -l app=tfvisualizer -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$APP_POD" ]; then
    kubectl exec $APP_POD -n tfvisualizer -- cat /etc/resolv.conf
else
    echo "No app pod found"
fi
echo ""

echo "6. Test basic DNS lookup from app pod:"
echo "-------------------------------------------"
if [ -n "$APP_POD" ]; then
    echo "Testing kubernetes.default resolution..."
    kubectl exec $APP_POD -n tfvisualizer -- nslookup kubernetes.default 2>&1
    echo ""

    echo "Testing kube-dns.kube-system resolution..."
    kubectl exec $APP_POD -n tfvisualizer -- nslookup kube-dns.kube-system 2>&1
fi
echo ""

echo "7. Checking if DigitalOcean DNS is working:"
echo "-------------------------------------------"
kubectl get pods -n kube-system | grep -i dns
echo ""

echo "============================================"
echo "Diagnostic Complete"
echo "============================================"
echo ""
echo "COMMON ISSUES:"
echo "- If no DNS pods exist: DNS service not deployed"
echo "- If DNS pods are not Running/Ready: Check logs above"
echo "- If resolv.conf is wrong: Pod DNS config issue"
echo "- For DigitalOcean: Check if cluster DNS is enabled"
echo ""
