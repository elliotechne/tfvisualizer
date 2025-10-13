# Apply All Kubernetes Deployment Fixes

## Changes Ready to Apply

All fixes have been implemented in the code. You need to apply them to your Kubernetes cluster.

---

## Files Modified (Ready for Deployment)

### 1. Application Probe Timing
**File:** `terraform/kubernetes.tf`

- **Liveness probe:** 30s → 90s (line 155)
- **Readiness probe:** 10s → 60s (line 166)

### 2. PostgreSQL Probe Configuration
**File:** `terraform/databases.tf`

- **Liveness probe:** Uses `postgres` user, 60s delay (line 81)
- **Readiness probe:** Uses `postgres` user, 30s delay (line 91)

### 3. Improved wait-for-db Script
**File:** `wait-for-db.sh`

- Two-phase connection check (PostgreSQL ready → Database ready)
- Better error messages

### 4. Docker Image Reference
**File:** `terraform/variables.tf`

- Removed duplicate registry from `docker_image` variable (line 165)

### 5. GHCR Authentication
**File:** `.github/workflows/terraform.yml`

- Added `packages: read` permission (line 197)
- Using `GHCR_PAT` for authentication (line 44)

---

## How to Apply Changes

### Step 1: Rebuild Docker Image (If wait-for-db.sh Changed)

The wait-for-db.sh script is copied into the Docker image during build. You need to rebuild and push:

```bash
# Build new image with updated wait-for-db.sh
docker build -t ghcr.io/elliotechne/tfvisualizer:latest .

# Login to GHCR
echo $GHCR_PAT | docker login ghcr.io -u elliotechne --password-stdin

# Push image
docker push ghcr.io/elliotechne/tfvisualizer:latest
```

**OR** trigger GitHub Actions workflow to build automatically:
```bash
git add .
git commit -m "Fix PostgreSQL connection and probe timing"
git push origin main
```

### Step 2: Apply Terraform Changes

```bash
# Navigate to terraform directory
cd terraform

# Review changes
terraform plan

# You should see updates to:
# - kubernetes_deployment.app (readiness/liveness probes)
# - kubernetes_stateful_set.postgres (readiness/liveness probes)

# Apply changes
terraform apply
```

Type `yes` when prompted.

### Step 3: Verify Deployment

```bash
# Watch pods restart with new configuration
kubectl get pods -n tfvisualizer -w

# Wait for all pods to be Running and Ready (1/1)
# Press Ctrl+C when done watching
```

---

## What Will Happen

### During Terraform Apply

1. **PostgreSQL StatefulSet updates:**
   - Pod will restart with new probes
   - Will take 30-60 seconds to become Ready
   - No data loss (PVC persists)

2. **Application Deployment updates:**
   - Rolling update (zero downtime if replicas > 1)
   - New pods with updated probe timing
   - Old pods terminate after new ones are Ready

### Expected Timeline

```
0s    terraform apply starts

30s   PostgreSQL pod restarts
      └─ New probes: pg_isready -U postgres
      └─ Delays: 30s readiness, 60s liveness

60s   PostgreSQL pod Ready ✅

65s   Application pods start rolling update
      └─ New pod created with updated probes
      └─ wait-for-db script runs (improved version)

120s  New application pod checks PostgreSQL
      └─ "PostgreSQL is accepting connections!"
      └─ "Database 'tfvisualizer' is ready!"
      └─ Migrations run

130s  Application binds to port 80

150s  Readiness probe starts (60s delay)
      └─ GET /health returns 200 OK ✅
      └─ Pod marked Ready ✅
      └─ Old pod terminates

190s  Liveness probe starts (90s delay)
      └─ GET /health returns 200 OK ✅

200s  Deployment complete ✅
```

**Total time:** ~3-4 minutes for full deployment

---

## Verification Commands

### Check All Pods

```bash
kubectl get pods -n tfvisualizer

# Expected output:
# NAME                                READY   STATUS    RESTARTS   AGE
# postgres-0                          1/1     Running   0          3m
# redis-0                             1/1     Running   0          3m
# tfvisualizer-app-xxxxx-yyy          1/1     Running   0          2m
```

All should show `1/1` Ready and `Running` status.

### Check for Probe Failures

```bash
# Check recent events
kubectl get events -n tfvisualizer --sort-by='.lastTimestamp' | grep -i "probe failed" | tail -20

# Should only show OLD events (before terraform apply)
# No new probe failures ✅
```

### Check Application Logs

```bash
# Get app pod name
APP_POD=$(kubectl get pods -n tfvisualizer -l app=tfvisualizer -o jsonpath='{.items[0].metadata.name}')

# View startup logs
kubectl logs $APP_POD -n tfvisualizer --tail=50

# Should see:
# Waiting for PostgreSQL at postgres.tfvisualizer.svc.cluster.local:5432...
# PostgreSQL is unavailable - attempt 1/60
# PostgreSQL is accepting connections!
# Waiting for database 'tfvisualizer' to be created - attempt 1/10
# Database 'tfvisualizer' is ready!
# Running database migrations...
# [INFO] Starting gunicorn 21.2.0
# [INFO] Listening at: http://0.0.0.0:80
```

### Check PostgreSQL Logs

```bash
kubectl logs postgres-0 -n tfvisualizer --tail=30

# Should see:
# database system is ready to accept connections
# (No "database tfuser does not exist" errors)
```

### Test Health Endpoint

```bash
# Port forward to app
kubectl port-forward -n tfvisualizer $APP_POD 8080:80

# Test in another terminal
curl http://localhost:8080/health

# Expected response:
# {
#   "status": "healthy",
#   "database": "connected",
#   "redis": "connected"
# }
```

---

## Current State vs Fixed State

### Current State (Before Apply)

```
Application Pod:
├─ Readiness probe: 10s delay ❌ Too early
├─ Liveness probe: 30s delay ❌ Too early
└─ wait-for-db: Old version ❌ Immediate database check

PostgreSQL Pod:
├─ Readiness probe: pg_isready -U tfuser -d tfvisualizer ❌ Database doesn't exist yet
├─ Liveness probe: pg_isready -U tfuser -d tfvisualizer ❌ Database doesn't exist yet
└─ Result: Probe failures, pod not Ready ❌

Result:
❌ "Readiness probe failed: connection refused"
❌ "PostgreSQL is unavailable"
❌ Pods never become Ready
```

### Fixed State (After Apply)

```
Application Pod:
├─ Readiness probe: 60s delay ✅ Waits for full startup
├─ Liveness probe: 90s delay ✅ Prevents restart during startup
└─ wait-for-db: Improved ✅ Two-phase check

PostgreSQL Pod:
├─ Readiness probe: pg_isready -U postgres (30s delay) ✅
├─ Liveness probe: pg_isready -U postgres (60s delay) ✅
└─ Result: Probes succeed, pod Ready ✅

Result:
✅ No probe failures during startup
✅ PostgreSQL becomes Ready quickly
✅ Application connects successfully
✅ All pods Running and Ready
```

---

## Rollback Plan

If something goes wrong, you can rollback:

```bash
# Get current deployment
kubectl get deployment tfvisualizer-app -n tfvisualizer -o yaml > deployment-backup.yaml

# Rollback deployment to previous version
kubectl rollout undo deployment/tfvisualizer-app -n tfvisualizer

# Or rollback Terraform
cd terraform
terraform plan -destroy  # Review what would be destroyed
# (Don't actually destroy unless necessary)
```

**Better approach:** Just fix the issue and re-apply Terraform.

---

## Troubleshooting After Apply

### Issue: Pods Still Showing Probe Failures

**Check:**
```bash
# Verify Terraform changes were applied
kubectl get deployment tfvisualizer-app -n tfvisualizer -o yaml | grep -A5 "readinessProbe"

# Should show:
# initialDelaySeconds: 60
```

**If still 10 seconds:**
- Terraform apply didn't succeed
- Re-run: `terraform apply`

### Issue: PostgreSQL Still Not Ready

**Check:**
```bash
kubectl describe pod postgres-0 -n tfvisualizer | grep -A10 "Probes"

# Should show:
# Liveness: exec [pg_isready -U postgres]
# Readiness: exec [pg_isready -U postgres]
```

**If still using `-U tfuser -d tfvisualizer`:**
- Terraform didn't update the StatefulSet
- May need to delete and recreate: `kubectl delete pod postgres-0 -n tfvisualizer`

### Issue: Application Can't Connect to Database

**Check logs:**
```bash
kubectl logs $APP_POD -n tfvisualizer | grep -i postgres

# Should show new wait-for-db messages:
# "PostgreSQL is accepting connections!"
# "Database 'tfvisualizer' is ready!"
```

**If still showing old messages:**
- Docker image not rebuilt with new wait-for-db.sh
- Rebuild and push image (see Step 1 above)

---

## Quick Apply Commands

```bash
# One-liner to apply everything
cd terraform && terraform apply -auto-approve

# Watch deployment progress
kubectl get pods -n tfvisualizer -w
```

---

## Summary

**All code changes are complete and ready to deploy.**

**Required actions:**

1. ✅ Rebuild Docker image (if wait-for-db.sh changed) OR push code to trigger GitHub Actions
2. ✅ Run `terraform apply` to update Kubernetes resources
3. ✅ Verify all pods become Ready (1/1)
4. ✅ Test application health endpoint

**Expected result:**
- No more "connection refused" errors
- No more "PostgreSQL is unavailable" messages
- All pods Running and Ready within 3-4 minutes

---

**Ready to deploy. Run `terraform apply` to fix all issues. ✅**
