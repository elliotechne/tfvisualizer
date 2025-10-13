# PostgreSQL Probe Database Name Fix

## Issue

PostgreSQL readiness and liveness probes failing with error:

```
2025-10-07 21:21:15.108 UTC [15081] FATAL:  database "tfuser" does not exist
```

---

## Root Cause

The `pg_isready` command was called with only the username parameter:

```bash
pg_isready -U tfuser
```

When `pg_isready` doesn't specify a database name with `-d`, it **defaults to using a database with the same name as the username**. In this case, it tried to connect to database `tfuser`, which doesn't exist.

**Our database configuration:**
- **Database name:** `tfvisualizer` ✅
- **Username:** `tfuser` ✅
- **Password:** From secrets ✅

The probe tried: `tfuser` database ❌
Should try: `tfvisualizer` database ✅

---

## Solution

Added the `-d tfvisualizer` parameter to specify the correct database name.

### Changes Made

**File:** `terraform/databases.tf`

**Before:**
```hcl
liveness_probe {
  exec {
    command = ["pg_isready", "-U", "tfuser"]  # ❌ Missing database name
  }
  initial_delay_seconds = 30
  period_seconds        = 10
  timeout_seconds       = 5
  failure_threshold     = 3
}

readiness_probe {
  exec {
    command = ["pg_isready", "-U", "tfuser"]  # ❌ Missing database name
  }
  initial_delay_seconds = 5
  period_seconds        = 5
  timeout_seconds       = 3
  failure_threshold     = 3
}
```

**After:**
```hcl
liveness_probe {
  exec {
    command = ["pg_isready", "-U", "tfuser", "-d", "tfvisualizer"]  # ✅ Added database name
  }
  initial_delay_seconds = 30
  period_seconds        = 10
  timeout_seconds       = 5
  failure_threshold     = 3
}

readiness_probe {
  exec {
    command = ["pg_isready", "-U", "tfuser", "-d", "tfvisualizer"]  # ✅ Added database name
  }
  initial_delay_seconds = 5
  period_seconds        = 5
  timeout_seconds       = 3
  failure_threshold     = 3
}
```

---

## How `pg_isready` Works

### Command Syntax

```bash
pg_isready [options]
```

**Common options:**
- `-h HOST` - Database server host (default: localhost)
- `-p PORT` - Database server port (default: 5432)
- `-U USER` - Database username
- `-d DBNAME` - Database name to connect to
- `-t SECONDS` - Timeout in seconds

### Default Behavior

If `-d` is not specified, `pg_isready` uses:
1. Database name from `-U` parameter (username)
2. Or `postgres` default database

**Our case:**
- We specified: `-U tfuser`
- `pg_isready` defaulted to: database `tfuser`
- Error: Database `tfuser` doesn't exist ❌

**Fix:**
- We now specify: `-U tfuser -d tfvisualizer`
- `pg_isready` connects to: database `tfvisualizer`
- Success: Database exists ✅

### Full Command Now

```bash
pg_isready -U tfuser -d tfvisualizer
```

**What it does:**
1. Connects to PostgreSQL as user `tfuser`
2. Tries to connect to database `tfvisualizer`
3. Returns exit code 0 if successful (server accepting connections)
4. Returns non-zero if connection fails

---

## PostgreSQL Database Configuration

### Environment Variables (databases.tf:38-60)

```hcl
env {
  name  = "POSTGRES_DB"
  value = "tfvisualizer"  # ✅ Database name
}

env {
  name  = "POSTGRES_USER"
  value = "tfuser"  # ✅ Username
}

env {
  name = "POSTGRES_PASSWORD"
  value_from {
    secret_key_ref {
      name = "database-credentials"
      key  = "postgres-password"
    }
  }
}
```

### Application Connection String (kubernetes.tf:53)

```hcl
DATABASE_URL = "postgresql://tfuser:${password}@postgres.tfvisualizer.svc.cluster.local:5432/tfvisualizer"
                             ^^^^^^                                                              ^^^^^^^^^^^^
                             User                                                                Database name
```

**Both match now:** ✅
- Probe uses: `tfuser` @ `tfvisualizer`
- App uses: `tfuser` @ `tfvisualizer`

---

## Verification

### Check Probe Success

After applying Terraform changes:

```bash
# Check PostgreSQL pod status
kubectl get pod postgres-0 -n tfvisualizer

# Expected output:
# NAME         READY   STATUS    RESTARTS   AGE
# postgres-0   1/1     Running   0          2m

# Check recent events (should show no probe failures)
kubectl describe pod postgres-0 -n tfvisualizer | grep -A5 "Liveness\|Readiness"
```

**Success indicators:**
- Pod shows `1/1` Ready ✅
- No "Liveness probe failed" events
- No "Readiness probe failed" events
- No FATAL errors in logs

### Check PostgreSQL Logs

```bash
# View PostgreSQL logs
kubectl logs postgres-0 -n tfvisualizer --tail=50

# Should see:
# LOG:  database system is ready to accept connections
# (No FATAL errors about database "tfuser" not existing)
```

### Test Connection Manually

```bash
# Exec into PostgreSQL pod
kubectl exec -it postgres-0 -n tfvisualizer -- bash

# Inside the pod, test the probe command
pg_isready -U tfuser -d tfvisualizer

# Expected output:
# /var/run/postgresql:5432 - accepting connections

# Exit code should be 0
echo $?
# 0
```

### Test from Application Pod

```bash
# Get app pod name
APP_POD=$(kubectl get pods -n tfvisualizer -l app=tfvisualizer -o jsonpath='{.items[0].metadata.name}')

# Check wait-for-db logs
kubectl logs $APP_POD -n tfvisualizer | grep -i postgres

# Should see:
# PostgreSQL is up and ready!
# Running database migrations...
```

---

## Impact

### Before Fix

```
0s    PostgreSQL pod starts
5s    Readiness probe runs: pg_isready -U tfuser
      └─ Tries to connect to database "tfuser" ❌
      └─ FATAL: database "tfuser" does not exist
      └─ Probe fails, pod not marked Ready
10s   Probe runs again: same error ❌
15s   Probe runs again: same error ❌
...   Continues failing indefinitely

App pod:
      └─ wait-for-db trying to connect
      └─ PostgreSQL is unavailable (pod not ready)
      └─ Never succeeds because PostgreSQL never becomes Ready
```

### After Fix

```
0s    PostgreSQL pod starts
30s   Database initialization complete
      └─ Database "tfvisualizer" created ✅
      └─ User "tfuser" created ✅
35s   Readiness probe runs: pg_isready -U tfuser -d tfvisualizer
      └─ Connects to database "tfvisualizer" ✅
      └─ Returns: accepting connections
      └─ Probe succeeds, pod marked Ready ✅

App pod:
      └─ wait-for-db detects PostgreSQL is ready ✅
      └─ Runs migrations successfully ✅
      └─ Starts application ✅
```

---

## Alternative Solutions

### Option 1: Use Default `postgres` Database (Not Recommended)

```hcl
command = ["pg_isready", "-U", "tfuser", "-d", "postgres"]
```

**Why not recommended:**
- Checks wrong database
- Doesn't verify `tfvisualizer` database exists
- App connects to `tfvisualizer`, probe should too

### Option 2: Use No Database Parameter (Not Recommended)

```hcl
command = ["pg_isready"]
```

**Why not recommended:**
- Defaults to database named after OS user (probably `postgres`)
- Inconsistent with actual usage
- Less explicit

### Option 3: Current Solution (Recommended) ✅

```hcl
command = ["pg_isready", "-U", "tfuser", "-d", "tfvisualizer"]
```

**Why recommended:**
- Explicitly specifies both user and database
- Matches actual application usage
- Clear and maintainable
- Verifies the exact database app will use

---

## Related Configuration

### PostgreSQL Initialization

When the PostgreSQL container starts for the first time, it:

1. **Creates database cluster** (if data directory is empty)
2. **Creates database** from `POSTGRES_DB` env var (`tfvisualizer`)
3. **Creates user** from `POSTGRES_USER` env var (`tfuser`)
4. **Sets password** from `POSTGRES_PASSWORD` env var
5. **Grants privileges** to user on database
6. **Starts server** and accepts connections

### Database Created

```sql
CREATE DATABASE tfvisualizer OWNER tfuser;
```

**Not created:**
```sql
-- This database does NOT exist:
CREATE DATABASE tfuser;  -- ❌ Never created
```

This is why the probe was failing - it was looking for a database that was never created.

---

## pg_isready Reference

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Server accepting connections ✅ |
| 1 | Server rejecting connections (startup, shutdown, recovery) |
| 2 | No response from server |
| 3 | No attempt made (bad parameters) |

### Example Usage

```bash
# Basic check (uses defaults)
pg_isready

# Check specific host
pg_isready -h postgres.tfvisualizer.svc.cluster.local

# Check with user and database
pg_isready -U tfuser -d tfvisualizer

# Check with timeout
pg_isready -U tfuser -d tfvisualizer -t 5

# Quiet mode (no output, just exit code)
pg_isready -q
```

### In Kubernetes Probes

```hcl
# Exec probe - runs command in container
exec {
  command = ["pg_isready", "-U", "tfuser", "-d", "tfvisualizer"]
}

# Could also use TCP probe (simpler but less specific)
tcp_socket {
  port = 5432
}
```

**Why we use exec probe:**
- Verifies PostgreSQL is actually accepting connections
- Not just that port is open
- More reliable than TCP probe for databases

---

## Testing Checklist

- [x] Updated PostgreSQL liveness probe with `-d tfvisualizer`
- [x] Updated PostgreSQL readiness probe with `-d tfvisualizer`
- [ ] Run `terraform apply` to update StatefulSet
- [ ] Verify postgres-0 pod becomes Ready (1/1)
- [ ] Check logs for no FATAL database errors
- [ ] Verify application pod connects successfully
- [ ] Confirm wait-for-db succeeds
- [ ] Test application health endpoint

---

## Apply Changes

```bash
# Navigate to terraform directory
cd terraform

# Review changes
terraform plan

# Apply changes
terraform apply -auto-approve

# Watch PostgreSQL pod
kubectl get pod postgres-0 -n tfvisualizer -w

# Should see:
# NAME         READY   STATUS    RESTARTS   AGE
# postgres-0   0/1     Running   0          10s
# postgres-0   1/1     Running   0          35s  ✅
```

---

## Summary

**Problem:** PostgreSQL probe trying to connect to database `tfuser` which doesn't exist

**Root Cause:** `pg_isready -U tfuser` defaults to database named `tfuser`

**Solution:** Added `-d tfvisualizer` to specify correct database name ✅

**Files Changed:**
- `terraform/databases.tf` - Lines 81 and 91

**Result:** PostgreSQL pod will now pass readiness checks and application can connect ✅

---

**PostgreSQL probe database name fixed. ✅**
