# wait-for-db Script Improvement

## Issue

Application showing "PostgreSQL is unavailable" even though PostgreSQL StatefulSet is running.

```
PostgreSQL is unavailable - attempt 1/60
PostgreSQL is unavailable - attempt 2/60
...
```

---

## Root Cause

The `wait-for-db.sh` script was immediately trying to connect to a specific database (`tfvisualizer`), but during PostgreSQL's first-time initialization:

1. **PostgreSQL starts** and begins accepting connections
2. **initdb runs** (if data directory is empty)
3. **postgres superuser is created**
4. **Custom database is created** (`tfvisualizer`)
5. **Custom user is created** (`tfuser`)
6. **Privileges are granted**

**The problem:** The script was trying to connect to `tfvisualizer` database at step 1, before steps 3-6 completed.

### Old Script Behavior

```bash
# Immediately tries to connect to specific database
psql -h postgres -U tfuser -d tfvisualizer -c '\q'
# ❌ Fails because database doesn't exist yet
```

---

## Solution

Improved the wait-for-db script to use a two-phase check:

### Phase 1: Check PostgreSQL Server Readiness

Use `pg_isready` to check if PostgreSQL is accepting connections at all:

```bash
pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER"
```

This succeeds as soon as PostgreSQL starts, even if specific databases aren't created yet.

### Phase 2: Check Database Availability

Once PostgreSQL is accepting connections, try connecting to the specific database:

```bash
psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c '\q'
```

This waits for the specific database to be created and accessible.

---

## Changes Made

**File:** `wait-for-db.sh`

### Before

```bash
echo "Waiting for PostgreSQL at ${DB_HOST}:${DB_PORT}..."

for i in {1..60}; do
  if PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c '\q' 2>/dev/null; then
    echo "PostgreSQL is up and ready!"
    # Continue with migrations...
  fi

  echo "PostgreSQL is unavailable - attempt $i/60"
  sleep 1
done
```

**Problem:** Immediately checks for specific database, which might not exist yet ❌

### After

```bash
echo "Waiting for PostgreSQL at ${DB_HOST}:${DB_PORT}..."

for i in {1..60}; do
  # Phase 1: Check if PostgreSQL is accepting connections
  if pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" > /dev/null 2>&1; then
    echo "PostgreSQL is accepting connections!"

    # Phase 2: Wait for specific database to be created
    for j in {1..10}; do
      if PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c '\q' 2>/dev/null; then
        echo "Database '$DB_NAME' is ready!"
        # Continue with migrations...
      fi

      echo "Waiting for database '$DB_NAME' to be created - attempt $j/10"
      sleep 2
    done

    echo "ERROR: Database '$DB_NAME' was not created"
    exit 1
  fi

  echo "PostgreSQL is unavailable - attempt $i/60"
  sleep 1
done
```

**Benefits:**
- ✅ Detects when PostgreSQL starts accepting connections
- ✅ Waits for specific database to be created
- ✅ Provides clearer error messages
- ✅ Gives PostgreSQL time to initialize

---

## PostgreSQL Probes Update

Also updated PostgreSQL StatefulSet probes to use the `postgres` superuser instead of `tfuser` during initialization:

**File:** `terraform/databases.tf`

### Before

```hcl
liveness_probe {
  exec {
    command = ["pg_isready", "-U", "tfuser", "-d", "tfvisualizer"]
  }
  initial_delay_seconds = 30
}

readiness_probe {
  exec {
    command = ["pg_isready", "-U", "tfuser", "-d", "tfvisualizer"]
  }
  initial_delay_seconds = 5
}
```

**Problem:**
- Tries to use `tfuser` which doesn't exist yet during initialization
- Tries to access `tfvisualizer` database which isn't created yet
- Too short initial delays

### After

```hcl
liveness_probe {
  exec {
    command = ["pg_isready", "-U", "postgres"]
  }
  initial_delay_seconds = 60
}

readiness_probe {
  exec {
    command = ["pg_isready", "-U", "postgres"]
  }
  initial_delay_seconds = 30
}
```

**Benefits:**
- ✅ Uses `postgres` superuser (always exists)
- ✅ No database specified (checks server readiness only)
- ✅ Longer delays allow initialization to complete

---

## How It Works Now

### Timeline

```
0s     PostgreSQL pod starts
       └─ Container begins, volume mounted

10s    initdb runs (if first startup)
       └─ Creates database cluster
       └─ Creates postgres superuser

25s    PostgreSQL starts accepting connections
       └─ pg_isready succeeds ✅

30s    [READINESS PROBE - PostgreSQL pod]
       └─ pg_isready -U postgres succeeds ✅
       └─ Pod marked Ready

35s    PostgreSQL initialization completes
       └─ Database 'tfvisualizer' created
       └─ User 'tfuser' created with password
       └─ Privileges granted

40s    [APPLICATION wait-for-db - Phase 1]
       └─ pg_isready -h postgres succeeds ✅
       └─ "PostgreSQL is accepting connections!"

42s    [APPLICATION wait-for-db - Phase 2]
       └─ psql -U tfuser -d tfvisualizer succeeds ✅
       └─ "Database 'tfvisualizer' is ready!"

45s    Database migrations run
       └─ flask db upgrade completes

50s    Application starts
       └─ Gunicorn binds to port 80
```

---

## Key Improvements

### 1. Two-Phase Connection Check

| Phase | Check | Purpose |
|-------|-------|---------|
| **1** | `pg_isready` | PostgreSQL server is running |
| **2** | `psql -d dbname` | Specific database exists and is accessible |

### 2. Better Error Messages

**Old messages:**
```
PostgreSQL is unavailable - attempt 1/60
PostgreSQL is unavailable - attempt 2/60
```
Hard to tell what's happening.

**New messages:**
```
PostgreSQL is unavailable - attempt 1/60
PostgreSQL is unavailable - attempt 2/60
PostgreSQL is accepting connections!
Waiting for database 'tfvisualizer' to be created - attempt 1/10
Database 'tfvisualizer' is ready!
Running database migrations...
```
Clear progression of what's happening.

### 3. Appropriate Timeouts

| Phase | Timeout | Reason |
|-------|---------|--------|
| **PostgreSQL server start** | 60 seconds | Enough for initialization |
| **Database creation** | 20 seconds (10 × 2s) | Database created quickly after server starts |

**Total possible wait:** 60s + 20s = 80 seconds maximum

---

## Environment Variables

The script supports multiple ways to configure database connection:

### Option 1: DATABASE_URL (Recommended)

```bash
DATABASE_URL="postgresql://tfuser:password@postgres.tfvisualizer.svc.cluster.local:5432/tfvisualizer"
```

Script automatically parses:
- Host: `postgres.tfvisualizer.svc.cluster.local`
- Port: `5432`
- User: `tfuser`
- Password: `password`
- Database: `tfvisualizer`

### Option 2: Individual Environment Variables

```bash
DB_HOST="postgres.tfvisualizer.svc.cluster.local"
DB_PORT="5432"
DB_USER="tfuser"
DB_PASSWORD="password"
DB_NAME="tfvisualizer"
```

### Option 3: Fallback Defaults

If not specified, defaults to:
```bash
DB_HOST="${POSTGRES_HOST:-localhost}"
DB_PORT="${POSTGRES_PORT:-5432}"
DB_USER="${POSTGRES_USER:-tfuser}"
DB_PASSWORD="${POSTGRES_PASSWORD:-tfpass}"
DB_NAME="${POSTGRES_DB:-tfvisualizer}"
```

---

## Testing

### Test Locally

```bash
# Set environment variables
export DB_HOST=localhost
export DB_PORT=5432
export DB_USER=tfuser
export DB_PASSWORD=yourpassword
export DB_NAME=tfvisualizer

# Run the script
./wait-for-db.sh echo "Database is ready!"
```

### Test in Docker

```dockerfile
CMD ["./wait-for-db.sh", "gunicorn", "app:create_app()"]
```

### Test in Kubernetes

```bash
# Check app pod logs
kubectl logs -n tfvisualizer <app-pod-name>

# Should see:
# Waiting for PostgreSQL at postgres.tfvisualizer.svc.cluster.local:5432...
# PostgreSQL is unavailable - attempt 1/60
# PostgreSQL is unavailable - attempt 2/60
# ...
# PostgreSQL is accepting connections!
# Waiting for database 'tfvisualizer' to be created - attempt 1/10
# Database 'tfvisualizer' is ready!
# Running database migrations...
# [INFO] Starting gunicorn
```

---

## Verification Commands

### Check PostgreSQL is Running

```bash
kubectl get pod postgres-0 -n tfvisualizer

# Should show:
# NAME         READY   STATUS    RESTARTS   AGE
# postgres-0   1/1     Running   0          2m
```

### Check Database Exists

```bash
kubectl exec -it postgres-0 -n tfvisualizer -- psql -U postgres -c "\l"

# Should list:
# tfvisualizer | tfuser | ...
```

### Check User Exists

```bash
kubectl exec -it postgres-0 -n tfvisualizer -- psql -U postgres -c "\du"

# Should list:
# tfuser | ...
```

### Test Connection from App Pod

```bash
APP_POD=$(kubectl get pods -n tfvisualizer -l app=tfvisualizer -o jsonpath='{.items[0].metadata.name}')

kubectl exec -it $APP_POD -n tfvisualizer -- sh -c '
  pg_isready -h $DB_HOST -p $DB_PORT -U $DB_USER && echo "✅ PostgreSQL is ready" || echo "❌ PostgreSQL not ready"
'
```

---

## Troubleshooting

### Issue: "PostgreSQL is unavailable" Never Resolves

**Check PostgreSQL pod:**
```bash
kubectl get pod postgres-0 -n tfvisualizer
kubectl logs postgres-0 -n tfvisualizer
```

**Common causes:**
- Pod in CrashLoopBackOff
- PVC not bound
- Insufficient resources
- Network policy blocking connection

### Issue: "PostgreSQL is accepting connections!" but Database Not Created

**Check PostgreSQL logs for initialization:**
```bash
kubectl logs postgres-0 -n tfvisualizer | grep -i "database\|tfvisualizer"
```

**Should see:**
```
CREATE DATABASE tfvisualizer
CREATE USER tfuser
GRANT ALL PRIVILEGES
```

**If missing:**
- Check `POSTGRES_DB` environment variable is set
- Check `POSTGRES_USER` environment variable is set
- Check pod has successfully completed initialization

### Issue: Connection Denied / Authentication Failed

**Check credentials:**
```bash
# Check secret exists
kubectl get secret database-credentials -n tfvisualizer

# Verify password matches
kubectl get secret database-credentials -n tfvisualizer -o jsonpath='{.data.postgres-password}' | base64 -d
```

**Test connection:**
```bash
kubectl exec -it postgres-0 -n tfvisualizer -- psql -U tfuser -d tfvisualizer
# Enter password when prompted
```

---

## Related Files

| File | Purpose | Changes |
|------|---------|---------|
| `wait-for-db.sh` | Application startup script | Two-phase connection check |
| `terraform/databases.tf` | PostgreSQL StatefulSet | Updated probes to use postgres user |
| `Dockerfile` | Container image | Uses wait-for-db.sh (no changes needed) |

---

## Summary

**Problem:** Application couldn't connect to PostgreSQL during initialization

**Root Cause:** Script tried connecting to specific database before PostgreSQL finished creating it

**Solution:** Two-phase check:
1. Wait for PostgreSQL server to accept connections (`pg_isready`)
2. Wait for specific database to exist (`psql -d dbname`)

**Additional Improvements:**
- PostgreSQL probes use `postgres` user (always exists)
- Increased probe initial delays
- Better log messages showing progress

**Result:** Application waits appropriately for PostgreSQL initialization ✅

---

**wait-for-db script improved for PostgreSQL initialization. ✅**
