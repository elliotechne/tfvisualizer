#!/bin/bash

NAMESPACE="tfvisualizer"

echo "=========================================="
echo "REGISTRATION ERROR DIAGNOSTICS"
echo "=========================================="
echo ""

APP_POD=$(kubectl get pods -n $NAMESPACE -l app=tfvisualizer -o jsonpath='{.items[0].metadata.name}')

if [ -z "$APP_POD" ]; then
  echo "ERROR: No app pods found!"
  exit 1
fi

echo "1. APP LOGS (last 100 lines - looking for errors)"
echo "=================================================="
kubectl logs $APP_POD -n $NAMESPACE --tail=100 | grep -i -E "(error|exception|traceback|failed|fatal)" -A 3 -B 3 || echo "No obvious errors in logs"
echo ""

echo "2. FULL APP LOGS (last 50 lines)"
echo "================================="
kubectl logs $APP_POD -n $NAMESPACE --tail=50
echo ""

echo "3. DATABASE CONNECTION TEST"
echo "==========================="
echo "Testing PostgreSQL connection from app pod..."
kubectl exec $APP_POD -n $NAMESPACE -- python3 -c "
import os
import psycopg2
try:
    conn = psycopg2.connect(os.environ['DATABASE_URL'])
    print('✓ Database connection successful')
    conn.close()
except Exception as e:
    print(f'✗ Database connection failed: {e}')
" 2>&1
echo ""

echo "4. REDIS CONNECTION TEST"
echo "========================"
echo "Testing Redis connection from app pod..."
kubectl exec $APP_POD -n $NAMESPACE -- python3 -c "
import os
import redis
try:
    r = redis.from_url(os.environ['REDIS_URL'])
    r.ping()
    print('✓ Redis connection successful')
except Exception as e:
    print(f'✗ Redis connection failed: {e}')
" 2>&1
echo ""

echo "5. ENVIRONMENT VARIABLES CHECK"
echo "=============================="
kubectl exec $APP_POD -n $NAMESPACE -- env | grep -E "(DATABASE_URL|REDIS_URL|SECRET_KEY|JWT_SECRET)" | sed 's/=.*/=***REDACTED***/'
echo ""

echo "6. DATABASE TABLES CHECK"
echo "========================"
echo "Checking if user table exists..."
kubectl exec postgres-0 -n $NAMESPACE -- psql -U tfuser -d tfvisualizer -c "\dt" 2>&1 | grep -i user || echo "User table might not exist"
echo ""

echo "7. CHECK IF MIGRATIONS HAVE RUN"
echo "==============================="
kubectl exec $APP_POD -n $NAMESPACE -- python3 -c "
from app.main import create_app
app = create_app()
with app.app_context():
    from flask_sqlalchemy import SQLAlchemy
    from sqlalchemy import inspect
    db = SQLAlchemy(app)
    inspector = inspect(db.engine)
    tables = inspector.get_table_names()
    print(f'Tables in database: {tables}')
" 2>&1
echo ""

echo "=========================================="
echo "DIAGNOSTICS COMPLETE"
echo "=========================================="
echo ""
echo "Try signing up again and immediately run:"
echo "  kubectl logs $APP_POD -n $NAMESPACE --tail=20 -f"
echo "This will show real-time logs of the registration attempt."
