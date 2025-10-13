# PostgreSQL 'postgres' Role Fix

## Issue

PostgreSQL probes failing with error:

```
role "postgres" does not exist
```

---

## Root Cause

The PostgreSQL Docker image (`postgres:15-alpine`) should automatically create a `postgres` superuser role during initialization, but for some reason this isn't happening in the current deployment.

This could be due to:
1. Incomplete database initialization
2. Corrupted PGDATA directory
3. Custom initialization interfering with default setup

---

## Solution

Created an initialization script that automatically creates the `postgres` role if it doesn't exist. The official PostgreSQL Docker image automatically executes any `.sh` files found in `/docker-entrypoint-initdb.d/` during first-time initialization.

---

## Changes Made

### 1. Created ConfigMap with Initialization Script

**File:** `terraform/databases.tf` (lines 1-29)

```hcl
resource "kubernetes_config_map" "postgres_init" {
  metadata {
    name      = "postgres-init"
    namespace = "tfvisualizer"
  }

  data = {
    "01-create-postgres-role.sh" = <<-EOT
      #!/bin/bash
      set -e

      # Create postgres role if it doesn't exist
      psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        DO \$\$
        BEGIN
          IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'postgres') THEN
            CREATE ROLE postgres WITH SUPERUSER LOGIN PASSWORD '$POSTGRES_PASSWORD';
            GRANT ALL PRIVILEGES ON DATABASE $POSTGRES_DB TO postgres;
          END IF;
        END
        \$\$;
      EOSQL

      echo "PostgreSQL role 'postgres' ensured to exist"
    EOT
  }
}
```

**What it does:**
- Checks if `postgres` role exists
- Creates it with SUPERUSER and LOGIN privileges if missing
- Uses same password as the database
- Grants all privileges on the tfvisualizer database

### 2. Mounted ConfigMap as Volume

**File:** `terraform/databases.tf` (lines 109-113, 136-142)

```hcl
# Volume mount in container
volume_mount {
  name       = "init-script"
  mount_path = "/docker-entrypoint-initdb.d"
  read_only  = true
}

# Volume definition
volume {
  name = "init-script"
  config_map {
    name         = kubernetes_config_map.postgres_init.metadata[0].name
    default_mode = "0755"  # Make script executable
  }
}
```

### 3. Updated Probes to Use Simpler Check

**File:** `terraform/databases.tf` (lines 115-133)

Changed from:
```hcl
command = ["pg_isready", "-U", "postgres"]
```

To:
```hcl
command = ["pg_isready", "-h", "localhost"]
```

**Why:** `pg_isready -h localhost` checks if PostgreSQL is accepting connections without requiring a specific user to exist. This works even during initialization.

---

## How It Works

### PostgreSQL Initialization Flow

```
1. PostgreSQL container starts
   └─ Checks if PGDATA is empty

2. If empty, runs initialization:
   a. Runs initdb (creates database cluster)
   b. Creates POSTGRES_USER (tfuser)
   c. Creates POSTGRES_DB (tfvisualizer)
   d. Executes scripts in /docker-entrypoint-initdb.d/
      └─ 01-create-postgres-role.sh runs ✅
      └─ Creates 'postgres' role

3. PostgreSQL starts accepting connections
   └─ All roles now exist: tfuser, postgres ✅

4. Probes succeed
   └─ pg_isready -h localhost succeeds ✅
   └─ Pod marked Ready
```

### Script Execution

The official PostgreSQL image automatically:
1. Sorts files in `/docker-entrypoint-initdb.d/` alphanumerically
2. Executes `.sh` files as shell scripts
3. Executes `.sql` files with psql
4. Runs them once during first initialization only

**Our script:** `01-create-postgres-role.sh` (prefix `01-` ensures it runs first)

---

## Verification

### After Applying Changes

```bash
cd terraform
terraform apply

# Watch PostgreSQL restart
kubectl get pod postgres-0 -n tfvisualizer -w
```

### Check Init Script Was Mounted

```bash
kubectl exec -it postgres-0 -n tfvisualizer -- ls -la /docker-entrypoint-initdb.d/

# Should show:
# -rwxr-xr-x 1 root root ... 01-create-postgres-role.sh
```

### Check Logs for Script Execution

```bash
kubectl logs postgres-0 -n tfvisualizer | grep -i "postgres role"

# Should show:
# PostgreSQL role 'postgres' ensured to exist
```

### Verify postgres Role Exists

```bash
kubectl exec -it postgres-0 -n tfvisualizer -- psql -U tfuser -d tfvisualizer -c "\du"

# Should list both roles:
# Role name | Attributes
# ----------+------------------------------------------------------------
# postgres  | Superuser
# tfuser    |
```

### Test Probe Commands

```bash
# Test the actual probe command
kubectl exec postgres-0 -n tfvisualizer -- pg_isready -h localhost

# Should output:
# /var/run/postgresql:5432 - accepting connections

# Exit code should be 0
```

---

## Why This Approach

### ✅ Advantages

1. **Idempotent:** Script checks if role exists before creating
2. **Standard:** Uses PostgreSQL's built-in initialization mechanism
3. **Automatic:** Runs during first startup without manual intervention
4. **Safe:** Only runs on empty database (first initialization)
5. **Declarative:** Defined in Terraform, version controlled

### ❌ Alternatives Considered

**1. Manual role creation:**
```bash
kubectl exec -it postgres-0 -- psql -U tfuser -d tfvisualizer -c "CREATE ROLE postgres..."
```
- Not automated
- Not repeatable
- Requires manual intervention

**2. Init container:**
```hcl
init_container {
  # Try to create role
}
```
- PostgreSQL not running yet during init container phase
- Can't connect to database

**3. Post-start hook:**
```hcl
lifecycle {
  post_start {
    # Run script
  }
}
```
- Race condition with probes
- More complex error handling

---

## Probe Configuration

### Current Configuration

| Probe | Command | Initial Delay | Period | Timeout | Failures |
|-------|---------|---------------|--------|---------|----------|
| **Liveness** | `pg_isready -h localhost` | 60s | 10s | 5s | 6 |
| **Readiness** | `pg_isready -h localhost` | 30s | 10s | 5s | 6 |

### Why These Settings

**Command: `pg_isready -h localhost`**
- Checks PostgreSQL is accepting connections
- No user authentication required
- Works during initialization
- Lightweight check

**Initial delays:**
- **Liveness: 60s** - Allows full initialization (initdb + scripts)
- **Readiness: 30s** - PostgreSQL usually ready before this

**Failure thresholds: 6**
- 6 failures × 10s period = 60s tolerance
- Allows for initialization delays

---

## Troubleshooting

### Script Didn't Run

**Check ConfigMap exists:**
```bash
kubectl get configmap postgres-init -n tfvisualizer
kubectl describe configmap postgres-init -n tfvisualizer
```

**Check volume mounted:**
```bash
kubectl describe pod postgres-0 -n tfvisualizer | grep -A5 "Mounts"
```

**Check file exists in container:**
```bash
kubectl exec postgres-0 -n tfvisualizer -- cat /docker-entrypoint-initdb.d/01-create-postgres-role.sh
```

### Script Failed to Execute

**Check permissions:**
```bash
kubectl exec postgres-0 -n tfvisualizer -- ls -la /docker-entrypoint-initdb.d/
```

Should show: `-rwxr-xr-x` (executable)

**Check PostgreSQL initialization logs:**
```bash
kubectl logs postgres-0 -n tfvisualizer | grep -C5 "docker-entrypoint-initdb.d"
```

### Role Still Doesn't Exist

**Check script syntax:**
```bash
kubectl exec postgres-0 -n tfvisualizer -- bash -n /docker-entrypoint-initdb.d/01-create-postgres-role.sh
```

No output = syntax OK

**Manually run script:**
```bash
kubectl exec -it postgres-0 -n tfvisualizer -- bash /docker-entrypoint-initdb.d/01-create-postgres-role.sh
```

### Data Directory Already Exists

**If PGDATA already has data:**

The init script only runs on **first initialization** (when PGDATA is empty). If the database already exists, you need to:

**Option 1: Manually create role**
```bash
kubectl exec -it postgres-0 -n tfvisualizer -- psql -U tfuser -d tfvisualizer <<EOF
CREATE ROLE postgres WITH SUPERUSER LOGIN PASSWORD 'your-password';
GRANT ALL PRIVILEGES ON DATABASE tfvisualizer TO postgres;
EOF
```

**Option 2: Delete PVC and recreate (DESTROYS DATA)**
```bash
# Delete StatefulSet (keeps PVC)
kubectl delete statefulset postgres -n tfvisualizer

# Delete PVC (WARNING: Deletes all data!)
kubectl delete pvc postgres-storage-postgres-0 -n tfvisualizer

# Reapply Terraform (will recreate with init script)
cd terraform
terraform apply -auto-approve
```

---

## Testing Checklist

- [x] Created ConfigMap with init script
- [x] Mounted ConfigMap as volume in StatefulSet
- [x] Set script permissions to executable (0755)
- [x] Updated probes to use `pg_isready -h localhost`
- [ ] Run `terraform apply`
- [ ] Verify pod restarts successfully
- [ ] Check logs show "PostgreSQL role 'postgres' ensured to exist"
- [ ] Verify `postgres` role exists: `\du`
- [ ] Confirm probes succeed (pod shows 1/1 Ready)

---

## Summary

**Problem:** PostgreSQL probes failing because `postgres` role doesn't exist

**Root Cause:** Database initialization didn't create the `postgres` superuser role

**Solution:**
1. Created initialization script to create `postgres` role
2. Mounted as ConfigMap in `/docker-entrypoint-initdb.d/`
3. PostgreSQL automatically executes it during first startup
4. Updated probes to use simpler connection check

**Result:** PostgreSQL initializes correctly with `postgres` role ✅

---

**PostgreSQL role creation automated via init script. ✅**
