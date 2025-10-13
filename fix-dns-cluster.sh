#!/bin/bash

echo "============================================"
echo "DNS Fix Script for DigitalOcean Kubernetes"
echo "============================================"
echo ""

echo "Step 1: Check if DNS pods exist"
echo "-------------------------------------------"
DNS_PODS=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | wc -l)
COREDNS_PODS=$(kubectl get pods -n kube-system -l k8s-app=coredns --no-headers 2>/dev/null | wc -l)

echo "kube-dns pods: $DNS_PODS"
echo "coredns pods: $COREDNS_PODS"
echo ""

if [ "$DNS_PODS" -eq 0 ] && [ "$COREDNS_PODS" -eq 0 ]; then
    echo "❌ NO DNS PODS FOUND!"
    echo ""
    echo "This is a critical cluster issue. Options:"
    echo "1. Recreate the cluster via Terraform"
    echo "2. Contact DigitalOcean support"
    echo "3. Try manual CoreDNS installation (risky)"
    echo ""
    read -p "Try manual CoreDNS installation? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Installing CoreDNS..."
        kubectl apply -f https://storage.googleapis.com/kubernetes-the-hard-way/coredns-1.8.yaml
    fi
else
    echo "✅ DNS pods exist"
    echo ""
    echo "Step 2: Check DNS pod status"
    echo "-------------------------------------------"
    kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
    kubectl get pods -n kube-system -l k8s-app=coredns -o wide
    echo ""

    echo "Step 3: Check DNS service"
    echo "-------------------------------------------"
    kubectl get svc kube-dns -n kube-system
    echo ""

    echo "Step 4: Restart DNS pods"
    echo "-------------------------------------------"
    read -p "Restart DNS pods to fix? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl delete pods -n kube-system -l k8s-app=kube-dns
        kubectl delete pods -n kube-system -l k8s-app=coredns
        echo "DNS pods deleted. Waiting for restart..."
        sleep 5
        kubectl get pods -n kube-system -l k8s-app=kube-dns
        kubectl get pods -n kube-system -l k8s-app=coredns
    fi
fi

echo ""
echo "Step 5: Test DNS after fix"
echo "-------------------------------------------"
APP_POD=$(kubectl get pods -n tfvisualizer -l app=tfvisualizer -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$APP_POD" ]; then
    echo "Testing from app pod..."
    sleep 10
    kubectl exec $APP_POD -n tfvisualizer -- nslookup kubernetes.default 2>&1
else
    echo "No app pod to test from"
fi

echo ""
echo "============================================"
echo "If DNS still doesn't work, you need to:"
echo "1. Destroy and recreate the cluster, OR"
echo "2. Use IP addresses as a workaround"
echo "============================================"
