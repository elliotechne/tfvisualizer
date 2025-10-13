#!/bin/bash

NAMESPACE="tfvisualizer"
APP_POD=$(kubectl get pods -n $NAMESPACE -l app=tfvisualizer -o jsonpath='{.items[0].metadata.name}')

echo "=========================================="
echo "APPLICATION DEBUG INFORMATION"
echo "=========================================="
echo ""

echo "1. List application files structure"
echo "===================================="
kubectl exec $APP_POD -n $NAMESPACE -- ls -la /app/
echo ""
kubectl exec $APP_POD -n $NAMESPACE -- ls -la /app/app/ 2>/dev/null || echo "No /app/app/ directory"
echo ""

echo "2. Check Flask app structure"
echo "============================"
kubectl exec $APP_POD -n $NAMESPACE -- find /app -name "*.py" -type f 2>/dev/null | head -20
echo ""

echo "3. Available Flask routes"
echo "========================="
kubectl exec $APP_POD -n $NAMESPACE -- python3 << 'EOF'
try:
    from app.main import create_app
    app = create_app()
    print("\nRegistered routes:")
    for rule in sorted(app.url_map.iter_rules(), key=lambda r: r.rule):
        methods = ','.join(sorted(rule.methods - {'HEAD', 'OPTIONS'}))
        print(f"  {rule.rule:40s} [{methods}]")
except Exception as e:
    print(f"Error loading app: {e}")
EOF
echo ""

echo "4. Check for registration-related code"
echo "======================================"
kubectl exec $APP_POD -n $NAMESPACE -- grep -r "register" /app/app/*.py 2>/dev/null | head -20 || echo "No registration code found"
echo ""

echo "5. Check templates directory"
echo "============================"
kubectl exec $APP_POD -n $NAMESPACE -- ls -la /app/templates/ 2>/dev/null || echo "No templates directory"
echo ""

echo "6. Test health endpoint"
echo "======================="
kubectl exec $APP_POD -n $NAMESPACE -- curl -s http://localhost:8080/health
echo ""
echo ""

echo "7. Test root endpoint"
echo "===================="
kubectl exec $APP_POD -n $NAMESPACE -- curl -s http://localhost:8080/ | head -50
echo ""

echo "=========================================="
echo ""
echo "To interactively debug, run:"
echo "  kubectl exec -it $APP_POD -n $NAMESPACE -- /bin/bash"
echo ""
echo "Then you can:"
echo "  - Explore the code: ls /app/app/"
echo "  - Check Python packages: pip list"
echo "  - Run Python shell: python3"
echo "  - View logs: tail -f /app/logs/*"
