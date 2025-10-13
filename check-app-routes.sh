#!/bin/bash

NAMESPACE="tfvisualizer"
APP_POD=$(kubectl get pods -n $NAMESPACE -l app=tfvisualizer -o jsonpath='{.items[0].metadata.name}')

echo "Checking Flask application routes..."
echo ""

kubectl exec $APP_POD -n $NAMESPACE -- python3 -c "
from app.main import create_app
app = create_app()
print('Available routes:')
print('='*50)
for rule in app.url_map.iter_rules():
    methods = ','.join(sorted(rule.methods - {'HEAD', 'OPTIONS'}))
    print(f'{rule.endpoint:30s} {methods:20s} {rule.rule}')
" 2>&1

echo ""
echo "Check the registration route above and use the correct endpoint path."
