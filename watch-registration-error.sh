#!/bin/bash

NAMESPACE="tfvisualizer"
APP_POD=$(kubectl get pods -n $NAMESPACE -l app=tfvisualizer -o jsonpath='{.items[0].metadata.name}')

echo "=========================================="
echo "WATCHING REGISTRATION ERRORS"
echo "=========================================="
echo ""
echo "App pod: $APP_POD"
echo ""
echo "Now try to register on the website..."
echo "Watching logs in real-time..."
echo ""
echo "=========================================="
echo ""

kubectl logs $APP_POD -n $NAMESPACE --tail=100 -f
