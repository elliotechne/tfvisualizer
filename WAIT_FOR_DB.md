# wait-for-db.sh - Database Readiness Script

## Purpose

Ensures the PostgreSQL database is ready and accepting connections before starting the Flask application. This prevents startup errors when the database container takes longer to initialize than the application container.

---

## Features

✅ Waits for PostgreSQL to be ready (up to 60 seconds)
✅ Automatically runs database migrations (`flask db upgrade`)
✅ Supports both `DATABASE_URL` and individual environment variables
✅ Graceful error handling and informative logging
✅ Works with Kubernetes, Docker Compose, and standalone deployments

---

## How It Works

```bash
1. Script starts and reads database connection details
   ↓
2. Parses DATABASE_URL OR uses individual env vars (DB_HOST, DB_PORT, etc.)
   ↓
3. Attempts to connect to PostgreSQL (max 60 attempts, 1 second apart)
   ↓
4. Once connected, runs flask db upgrade (if Flask is available)
   ↓
5. Executes the main application command (gunicorn)
```

---

## Configuration

### Method 1: DATABASE_URL (Recommended)

```bash
export DATABASE_URL="postgresql://tfuser:tfpass@localhost:5432/tfvisualizer"
```

Script automatically extracts:
- Host: `localhost`
- Port: `5432`
- User: `tfuser`
- Password: `tfpass`
- Database: `tfvisualizer`

### Method 2: Individual Environment Variables

```bash
export DB_HOST="localhost"          # or POSTGRES_HOST
export DB_PORT="5432"              # or POSTGRES_PORT
export DB_USER="tfuser"            # or POSTGRES_USER
export DB_PASSWORD="tfpass"        # or POSTGRES_PASSWORD
export DB_NAME="tfvisualizer"      # or POSTGRES_DB
```

### Default Values

If no environment variables are set, defaults are:
- Host: `localhost`
- Port: `5432`
- User: `tfuser`
- Password: `tfpass`
- Database: `tfvisualizer`

---

## Usage

### Docker

**Dockerfile:**
```dockerfile
# Copy wait-for-db script
COPY wait-for-db.sh /usr/local/bin/wait-for-db.sh
RUN chmod +x /usr/local/bin/wait-for-db.sh

# Use in CMD
CMD ["wait-for-db.sh", "gunicorn", "--bind", "0.0.0.0:80", "app.main:create_app()"]
```

**docker-compose.yml:**
```yaml
services:
  app:
    build: .
    environment:
      - DATABASE_URL=postgresql://tfuser:tfpass@postgres:5432/tfvisualizer
    depends_on:
      - postgres
    command: wait-for-db.sh gunicorn --bind 0.0.0.0:80 'app.main:create_app()'

  postgres:
    image: postgres:15
    environment:
      - POSTGRES_USER=tfuser
      - POSTGRES_PASSWORD=tfpass
      - POSTGRES_DB=tfvisualizer
```

### Kubernetes

**Deployment manifest:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tfvisualizer-app
spec:
  template:
    spec:
      containers:
      - name: app
        image: ghcr.io/elliotechne/tfvisualizer:latest
        command: ["/bin/bash", "-c"]
        args: ["wait-for-db.sh gunicorn --bind 0.0.0.0:80 'app.main:create_app()'"]
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: app-config
              key: DATABASE_URL
```

### Local Development

```bash
# Run manually
./wait-for-db.sh python app/main.py

# Or with gunicorn
./wait-for-db.sh gunicorn --bind 0.0.0.0:80 'app.main:create_app()'
```

---

## Script Behavior

### Success Flow

```
$ ./wait-for-db.sh gunicorn 'app.main:create_app()'

Waiting for PostgreSQL at postgres.tfvisualizer.svc.cluster.local:5432...
PostgreSQL is unavailable - attempt 1/60
PostgreSQL is unavailable - attempt 2/60
PostgreSQL is up and ready!
Running database migrations...
INFO  [alembic.runtime.migration] Running upgrade -> abc123
SUCCESS: Database is ready
[2024-10-07 12:00:00] [INFO] Starting gunicorn 20.1.0
```

### Timeout Flow

```
$ ./wait-for-db.sh gunicorn 'app.main:create_app()'

Waiting for PostgreSQL at wrong-host:5432...
PostgreSQL is unavailable - attempt 1/60
PostgreSQL is unavailable - attempt 2/60
...
PostgreSQL is unavailable - attempt 60/60
ERROR: PostgreSQL did not become available in time
(exits with code 1)
```

---

## Database Migrations

The script automatically runs `flask db upgrade` if:
1. Flask CLI is available in the container
2. PostgreSQL connection is successful
3. Migration files exist in `migrations/` directory

### Migration Commands

Migrations are managed by Flask-Migrate (Alembic):

```bash
# Initialize migrations (first time only)
flask db init

# Create a new migration
flask db migrate -m "Add user table"

# Apply migrations
flask db upgrade

# Rollback one migration
flask db downgrade

# Show current revision
flask db current
```

---

## Environment Variable Priority

The script checks variables in this order:

1. **DATABASE_URL** (highest priority)
   - If set, all other variables are ignored
   - Format: `postgresql://user:pass@host:port/dbname`

2. **DB_* variables** (medium priority)
   - `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`

3. **POSTGRES_* variables** (low priority)
   - `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`

4. **Default values** (fallback)
   - Used if no environment variables are set

---

## Troubleshooting

### Issue: Script times out after 60 seconds

**Possible Causes:**
1. PostgreSQL is not running
2. Wrong hostname or port
3. Network connectivity issues
4. PostgreSQL not finished initializing

**Solutions:**
```bash
# Check if PostgreSQL is running
kubectl get pods -n tfvisualizer | grep postgres

# Check PostgreSQL logs
kubectl logs postgres-0 -n tfvisualizer

# Test connection manually
psql -h postgres.tfvisualizer.svc.cluster.local -U tfuser -d tfvisualizer

# Increase timeout in wait-for-db.sh
# Change: for i in {1..60}
# To:     for i in {1..120}  # 2 minutes
```

### Issue: Database connection works but migrations fail

**Possible Causes:**
1. Migration files not copied to container
2. `flask` command not available
3. Database permissions issue

**Solutions:**
```bash
# Check if migrations directory exists
docker exec -it <container> ls -la /app/migrations

# Check if flask is installed
docker exec -it <container> which flask

# Run migrations manually
docker exec -it <container> flask db upgrade

# Check database permissions
psql -U tfuser -d tfvisualizer -c "SHOW search_path;"
```

### Issue: "command not found: wait-for-db.sh"

**Possible Causes:**
1. Script not copied to container
2. Script not in PATH
3. Script not executable

**Solutions:**
```bash
# Check if script exists
docker exec -it <container> ls -la /usr/local/bin/wait-for-db.sh

# Make it executable
chmod +x wait-for-db.sh

# Use absolute path in Dockerfile
CMD ["/usr/local/bin/wait-for-db.sh", "gunicorn", "..."]
```

### Issue: Works locally, fails in Kubernetes

**Possible Causes:**
1. Service DNS not resolving
2. Network policies blocking connection
3. Wrong service name

**Solutions:**
```bash
# Test DNS resolution from pod
kubectl exec -it tfvisualizer-app-xxx -- nslookup postgres.tfvisualizer.svc.cluster.local

# Check service exists
kubectl get svc -n tfvisualizer

# Use full DNS name
# Format: <service>.<namespace>.svc.cluster.local
export DATABASE_URL="postgresql://tfuser:tfpass@postgres.tfvisualizer.svc.cluster.local:5432/tfvisualizer"
```

---

## Testing

### Test 1: Manual Execution

```bash
# Set environment variables
export DATABASE_URL="postgresql://tfuser:tfpass@localhost:5432/tfvisualizer"

# Run script with echo command
./wait-for-db.sh echo "Database is ready"

# Expected output:
# Waiting for PostgreSQL at localhost:5432...
# PostgreSQL is up and ready!
# Running database migrations...
# Database is ready
```

### Test 2: With Docker Compose

```bash
# Start services
docker-compose up -d postgres

# Wait for postgres to initialize
sleep 10

# Start app (uses wait-for-db.sh)
docker-compose up app

# Check logs
docker-compose logs app | grep "PostgreSQL"
```

### Test 3: Connection Timeout

```bash
# Set wrong hostname
export DB_HOST="nonexistent-host"

# Run script (should timeout after 60 seconds)
timeout 65 ./wait-for-db.sh echo "Success"

# Expected: Script exits with error code 1
echo $?  # Should print 1
```

---

## Integration with Terraform

The wait-for-db script is referenced in Terraform Kubernetes deployment:

**File:** `terraform/kubernetes.tf`

```hcl
resource "kubernetes_deployment" "tfvisualizer" {
  spec {
    template {
      spec {
        container {
          name  = "tfvisualizer"
          image = "ghcr.io/elliotechne/tfvisualizer:latest"

          # wait-for-db.sh is included in the Docker image
          command = ["/bin/bash", "-c"]
          args = ["wait-for-db.sh gunicorn --bind 0.0.0.0:80 'app.main:create_app()'"]

          env {
            name  = "DATABASE_URL"
            value = "postgresql://tfuser:${var.postgres_password}@postgres.${kubernetes_namespace.tfvisualizer.metadata[0].name}.svc.cluster.local:5432/tfvisualizer"
          }
        }
      }
    }
  }
}
```

---

## Best Practices

### ✅ DO:
- Use `DATABASE_URL` for simplicity
- Set reasonable timeout (60 seconds default)
- Run migrations automatically
- Log connection attempts for debugging
- Use service DNS names in Kubernetes (`postgres.namespace.svc.cluster.local`)

### ❌ DON'T:
- Hardcode database credentials in script
- Use infinite loops (always have a timeout)
- Skip error handling
- Run migrations manually in production
- Use `localhost` in Kubernetes (use service names)

---

## Related Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Copies wait-for-db.sh to container and sets CMD |
| `terraform/kubernetes.tf` | References script in Kubernetes deployment |
| `docker-compose.yml` | Uses script for local development |
| `app/main.py` | Application that starts after database is ready |
| `migrations/` | Database migration files run by script |

---

## Related Documentation

- [DATABASE_ARCHITECTURE.md](DATABASE_ARCHITECTURE.md) - Database setup and operations
- [INFRASTRUCTURE_AS_CODE.md](INFRASTRUCTURE_AS_CODE.md) - Complete infrastructure overview
- [KUBERNETES_DEPLOYMENT.md](KUBERNETES_DEPLOYMENT.md) - Kubernetes deployment guide

---

**wait-for-db.sh ensures your application starts reliably every time. ✅**
