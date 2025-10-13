# PostgreSQL Troubleshooting Guide

## Issue

Application shows "PostgreSQL is unavailable" during startup, preventing the pod from becoming ready.

---

## Diagnostic Commands

### 1. Check PostgreSQL Pod Status

```bash
# List all pods in tfvisualizer namespace
kubectl get pods -n tfvisualizer

# Expected output:
# NAME                                READY   STATUS    RESTARTS   AGE
# postgres-0                          1/1     Running   0          5m
# tfvisualizer-app-xxxxx-yyy          0/1     Running   0          2m
```

**Look for:**
- `postgres-0` pod status
- Should be `Running` with `1/1` ready
- If `Pending`, `CrashLoopBackOff`, or `Error` → PostgreSQL has issues

### 2. Check PostgreSQL Logs

```bash
# View PostgreSQL pod logs
kubectl logs -n tfvisualizer postgres-0 --tail=100

# Follow logs in real-time
kubectl logs -n tfvisualizer postgres-0 -f
```

**Look for:**
- `database system is ready to accept connections` ✅ Good
- `FATAL: data directory "/var/lib/postgresql/data/pgdata" has wrong ownership` ❌ Permission issue
- `FATAL: could not create lock file` ❌ Permission issue
- `initdb: error: directory "/var/lib/postgresql/data/pgdata" exists but is not empty` ❌ Volume issue

### 3. Check Persistent Volume Claim

```bash
# Check PVC status
kubectl get pvc -n tfvisualizer

# Expected output:
# NAME                          STATUS   VOLUME    CAPACITY   ACCESS MODES   STORAGECLASS
# postgres-storage-postgres-0   Bound    pvc-xxx   20Gi       RWO            do-block-storage
```

**Look for:**
- Status should be `Bound` ✅
- If `Pending` → Storage provisioning issue
- If `Lost` → Volume was deleted

### 4. Describe PostgreSQL Pod

```bash
# Get detailed pod information
kubectl describe pod postgres-0 -n tfvisualizer

# Look at Events section at the bottom
```

**Common Events:**
- `Successfully pulled image` ✅ Good
- `FailedMount: Unable to attach or mount volumes` ❌ Storage issue
- `FailedScheduling: 0/3 nodes are available` ❌ Resource issue
- `Back-off restarting failed container` ❌ Crash loop

### 5. Check PostgreSQL Service

```bash
# Check if PostgreSQL service exists
kubectl get service postgres -n tfvisualizer

# Expected output:
# NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)    AGE
# postgres   ClusterIP   None         <none>        5432/TCP   5m
```

### 6. Test Database Connection from App Pod

```bash
# Get app pod name
APP_POD=$(kubectl get pods -n tfvisualizer -l app=tfvisualizer -o jsonpath='{.items[0].metadata.name}')

# Exec into app pod and test connection
kubectl exec -it -n tfvisualizer $APP_POD -- bash

# Inside the pod:
apt-get update && apt-get install -y postgresql-client

# Test connection
psql -h postgres.tfvisualizer.svc.cluster.local -U tfuser -d tfvisualizer -c "SELECT 1;"

# You'll be prompted for password (from secrets)
```

---

## Common Issues and Solutions

### Issue 1: PostgreSQL Pod in CrashLoopBackOff

**Symptoms:**
```bash
kubectl get pods -n tfvisualizer
# postgres-0   0/1   CrashLoopBackOff   5   3m
```

**Causes:**
1. Permission issues on data directory
2. Corrupted data directory
3. Insufficient resources
4. Invalid configuration

**Solution A: Check Logs**
```bash
kubectl logs -n tfvisualizer postgres-0 --previous
```

**Solution B: Delete and Recreate PVC (CAUTION: Deletes data)**
```bash
# Delete StatefulSet (keeps PVC)
kubectl delete statefulset postgres -n tfvisualizer

# Delete PVC (WARNING: This deletes all database data!)
kubectl delete pvc postgres-storage-postgres-0 -n tfvisualizer

# Reapply Terraform to recreate
cd terraform
terraform apply -auto-approve
```

### Issue 2: PVC Stuck in Pending

**Symptoms:**
```bash
kubectl get pvc -n tfvisualizer
# NAME                          STATUS    VOLUME   CAPACITY   ACCESS MODES
# postgres-storage-postgres-0   Pending                       do-block-storage
```

**Causes:**
1. Storage class not available
2. No available storage nodes
3. Quota exceeded
4. DigitalOcean volume provisioning issue

**Solution:**
```bash
# Check storage class exists
kubectl get storageclass

# Should show:
# NAME                         PROVISIONER                 RECLAIMPOLICY
# do-block-storage (default)   dobs.csi.digitalocean.com   Delete

# Describe PVC for more details
kubectl describe pvc postgres-storage-postgres-0 -n tfvisualizer

# Check events for provisioning errors
```

**If storage class missing, check DigitalOcean CSI driver:**
```bash
kubectl get pods -n kube-system | grep csi
```

### Issue 3: Wrong Ownership on Data Directory

**Symptoms in logs:**
```
FATAL: data directory "/var/lib/postgresql/data/pgdata" has wrong ownership
The server must be started by the user that owns the data directory.
```

**Solution:**
```bash
# Delete the StatefulSet and PVC, recreate fresh
kubectl delete statefulset postgres -n tfvisualizer
kubectl delete pvc postgres-storage-postgres-0 -n tfvisualizer

# Wait for deletion
kubectl get pvc -n tfvisualizer

# Reapply Terraform
cd terraform
terraform apply -auto-approve
```

### Issue 4: PostgreSQL Taking Too Long to Start

**Symptoms:**
- Pod shows `Running` but not `Ready`
- App logs: "PostgreSQL is unavailable - attempt 30/60"

**Causes:**
1. First-time initialization (creating database cluster)
2. Large volume taking time to attach
3. Slow disk I/O

**Solution:**
This is often **normal** for first startup. PostgreSQL initialization can take 1-3 minutes.

**Wait and monitor:**
```bash
# Watch pod status
watch kubectl get pods -n tfvisualizer

# Watch logs
kubectl logs -n tfvisualizer postgres-0 -f
```

**Look for this in logs:**
```
PostgreSQL init process complete; ready for start up.
LOG:  database system is ready to accept connections
```

### Issue 5: Incorrect Database Credentials

**Symptoms in app logs:**
```
FATAL: password authentication failed for user "tfuser"
```

**Solution:**
```bash
# Check database credentials secret
kubectl get secret database-credentials -n tfvisualizer -o yaml

# Verify postgres-password is set
kubectl get secret database-credentials -n tfvisualizer -o jsonpath='{.data.postgres-password}' | base64 -d
echo

# Should match your terraform.tfvars postgres_password
```

**If password mismatch:**
```bash
# Update Terraform variable
# Edit terraform/terraform.tfvars and set correct password

# Reapply Terraform
cd terraform
terraform apply -auto-approve

# Restart PostgreSQL pod to use new credentials
kubectl delete pod postgres-0 -n tfvisualizer
```

### Issue 6: PostgreSQL Out of Memory

**Symptoms:**
```bash
kubectl describe pod postgres-0 -n tfvisualizer
# Reason: OOMKilled
```

**Solution:**
Increase PostgreSQL memory limits in `terraform/databases.tf`:

```hcl
resources {
  requests = {
    cpu    = "500m"
    memory = "1Gi"
  }
  limits = {
    cpu    = "2000m"
    memory = "4Gi"  # Increase if needed
  }
}
```

Then apply:
```bash
cd terraform
terraform apply -auto-approve
```

---

## PostgreSQL Startup Timeline

### Normal Startup (First Time)

```
0s    Pod scheduled, PVC provisioning starts
15s   PVC bound, volume attached to node
20s   Container starts, postgres:15-alpine image pulled
25s   PostgreSQL initdb starts (creating database cluster)
45s   initdb complete, PostgreSQL starting
50s   Database system is ready to accept connections ✅
55s   Readiness probe succeeds, pod marked Ready
```

**Total time: 50-60 seconds for first startup**

### Subsequent Restarts

```
0s    Pod scheduled (PVC already exists)
5s    Volume attached
10s   Container starts
15s   PostgreSQL starts (no initdb needed)
20s   Database system is ready to accept connections ✅
25s   Readiness probe succeeds, pod marked Ready
```

**Total time: 20-30 seconds**

---

## Quick Diagnosis Script

Save this as `diagnose-postgres.sh`:

```bash
#!/bin/bash

NAMESPACE="tfvisualizer"

echo "=== PostgreSQL Pod Status ==="
kubectl get pods -n $NAMESPACE | grep postgres

echo -e "\n=== PostgreSQL PVC Status ==="
kubectl get pvc -n $NAMESPACE | grep postgres

echo -e "\n=== PostgreSQL Service ==="
kubectl get service postgres -n $NAMESPACE

echo -e "\n=== PostgreSQL Pod Events (Last 10) ==="
kubectl get events -n $NAMESPACE --field-selector involvedObject.name=postgres-0 --sort-by='.lastTimestamp' | tail -10

echo -e "\n=== PostgreSQL Logs (Last 20 lines) ==="
kubectl logs -n $NAMESPACE postgres-0 --tail=20 2>/dev/null || echo "Pod not ready or not found"

echo -e "\n=== Check from App Pod ==="
APP_POD=$(kubectl get pods -n $NAMESPACE -l app=tfvisualizer -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$APP_POD" ]; then
    echo "Testing connection from $APP_POD..."
    kubectl exec -n $NAMESPACE $APP_POD -- sh -c 'timeout 2 nc -zv postgres.tfvisualizer.svc.cluster.local 5432' 2>&1 || echo "Connection failed"
else
    echo "No app pods found"
fi
```

Make executable and run:
```bash
chmod +x diagnose-postgres.sh
./diagnose-postgres.sh
```

---

## Step-by-Step Troubleshooting

### Step 1: Verify Pod Exists
```bash
kubectl get pods -n tfvisualizer | grep postgres
```

**If no postgres pod exists:**
- Check Terraform applied successfully
- Run: `cd terraform && terraform apply`

### Step 2: Check Pod Status
```bash
kubectl get pod postgres-0 -n tfvisualizer
```

**Status meanings:**
- `Pending` → Scheduling or volume attachment issue
- `Running 0/1` → Pod running but not ready (normal during startup)
- `Running 1/1` → Pod ready ✅
- `CrashLoopBackOff` → Pod keeps crashing
- `Error` → Pod failed to start

### Step 3: View Logs
```bash
kubectl logs postgres-0 -n tfvisualizer --tail=50
```

**Key log lines:**
- ✅ `database system is ready to accept connections`
- ❌ `FATAL:` anything → Critical error
- ❌ `PANIC:` anything → Critical error
- ⚠️ `WARNING:` → Non-critical but investigate

### Step 4: Check Resources
```bash
kubectl describe pod postgres-0 -n tfvisualizer | grep -A5 "Limits\|Requests"
```

**Verify:**
- Memory request: 1Gi
- Memory limit: 4Gi
- CPU request: 500m
- CPU limit: 2000m

### Step 5: Check Volume
```bash
kubectl describe pvc postgres-storage-postgres-0 -n tfvisualizer
```

**Verify:**
- Status: Bound ✅
- Capacity: 20Gi
- StorageClass: do-block-storage

### Step 6: Test Connection
```bash
# Port-forward PostgreSQL
kubectl port-forward -n tfvisualizer postgres-0 5432:5432

# In another terminal, test connection
psql -h localhost -U tfuser -d tfvisualizer -c "SELECT version();"
# Password from terraform.tfvars postgres_password
```

---

## PostgreSQL Configuration Reference

### Current Configuration (databases.tf)

```hcl
resource "kubernetes_stateful_set" "postgres" {
  metadata {
    name      = "postgres"
    namespace = "tfvisualizer"
  }

  spec {
    replicas     = 1
    service_name = "postgres"

    template {
      spec {
        container {
          name  = "postgres"
          image = "postgres:15-alpine"

          env {
            name  = "POSTGRES_DB"
            value = "tfvisualizer"
          }
          env {
            name  = "POSTGRES_USER"
            value = "tfuser"
          }
          env {
            name  = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = "database-credentials"
                key  = "postgres-password"
              }
            }
          }

          resources {
            requests = {
              cpu    = "500m"
              memory = "1Gi"
            }
            limits = {
              cpu    = "2000m"
              memory = "4Gi"
            }
          }

          volume_mount {
            name       = "postgres-storage"
            mount_path = "/var/lib/postgresql/data"
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "postgres-storage"
      }
      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = "do-block-storage"
        resources {
          requests = {
            storage = "20Gi"
          }
        }
      }
    }
  }
}
```

---

## When to Delete and Recreate

### ⚠️ CAUTION: Deleting PVC Destroys Data

**Only delete PVC if:**
1. Development/testing environment
2. Database is corrupted beyond repair
3. No important data exists
4. You have backups

**Never delete PVC in production without backup!**

### Safe Recreation Steps

```bash
# 1. Backup data first (if possible)
kubectl exec -n tfvisualizer postgres-0 -- pg_dump -U tfuser tfvisualizer > backup.sql

# 2. Delete StatefulSet (keeps PVC and data)
kubectl delete statefulset postgres -n tfvisualizer

# 3. Only if absolutely necessary, delete PVC (destroys data!)
kubectl delete pvc postgres-storage-postgres-0 -n tfvisualizer

# 4. Reapply Terraform
cd terraform
terraform apply -auto-approve

# 5. Wait for PostgreSQL to be ready
kubectl wait --for=condition=ready pod/postgres-0 -n tfvisualizer --timeout=180s

# 6. Restore data (if deleted PVC)
kubectl exec -i -n tfvisualizer postgres-0 -- psql -U tfuser tfvisualizer < backup.sql
```

---

## Summary Checklist

Run through this checklist to diagnose PostgreSQL issues:

- [ ] Check pod status: `kubectl get pods -n tfvisualizer | grep postgres`
- [ ] Check PVC status: `kubectl get pvc -n tfvisualizer`
- [ ] View logs: `kubectl logs postgres-0 -n tfvisualizer`
- [ ] Check events: `kubectl describe pod postgres-0 -n tfvisualizer`
- [ ] Verify service: `kubectl get svc postgres -n tfvisualizer`
- [ ] Test connection: Port-forward and `psql` connect
- [ ] Check resources: Memory and CPU sufficient
- [ ] Verify credentials: Secret matches terraform.tfvars

---

**PostgreSQL troubleshooting guide ready. Check pod status and logs to diagnose the issue. ✅**
