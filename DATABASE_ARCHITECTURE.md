# Database Architecture - PostgreSQL & Redis on DOKS

TFVisualizer uses PostgreSQL and Redis running as StatefulSets within the DOKS cluster.

---

## 🎯 Architecture Overview

### Why Run Databases on Kubernetes?

**Cost Savings:**
- DigitalOcean Managed PostgreSQL: $60/month
- DigitalOcean Managed Redis: $15/month
- **Total Managed**: $75/month

vs.

- DOKS Block Storage (20GB): $2/month
- DOKS Block Storage (5GB): $0.50/month
- **Total on DOKS**: $2.50/month

**Savings: ~$72.50/month (97% reduction!)**

**Benefits:**
- ✅ Lower cost
- ✅ All services in one cluster
- ✅ No external network latency
- ✅ Simplified infrastructure
- ✅ Easier local development matching

**Trade-offs:**
- ⚠️ Manual backup management
- ⚠️ No automatic failover (single replica)
- ⚠️ Requires more Kubernetes expertise
- ⚠️ Shared cluster resources

---

## 📊 Database Configuration

### PostgreSQL StatefulSet

**Specs:**
- **Image**: postgres:15-alpine
- **Replicas**: 1
- **CPU**: 500m request, 2000m limit
- **Memory**: 1Gi request, 4Gi limit
- **Storage**: 20Gi persistent volume (do-block-storage)

**Configuration:**
```yaml
Database: tfvisualizer
User: tfuser
Password: Stored in kubernetes secret
Port: 5432
PGDATA: /var/lib/postgresql/data/pgdata
```

**Service DNS:**
```
postgres.tfvisualizer.svc.cluster.local
```

**Health Checks:**
- Liveness: `pg_isready -U tfuser` every 10s
- Readiness: `pg_isready -U tfuser` every 5s

### Redis StatefulSet

**Specs:**
- **Image**: redis:7-alpine
- **Replicas**: 1
- **CPU**: 250m request, 1000m limit
- **Memory**: 512Mi request, 1Gi limit
- **Storage**: 5Gi persistent volume (do-block-storage)

**Configuration:**
```yaml
Port: 6379
Password: Stored in kubernetes secret
Persistence: AOF enabled
Max Memory: 512mb
Eviction Policy: allkeys-lru
```

**Service DNS:**
```
redis.tfvisualizer.svc.cluster.local
```

**Health Checks:**
- Liveness: `redis-cli ping` every 10s
- Readiness: `redis-cli ping` every 5s

---

## 🔐 Connection Details

### From Application Pods (within cluster)

**PostgreSQL:**
```bash
# Connection string
postgresql://tfuser:PASSWORD@postgres.tfvisualizer.svc.cluster.local:5432/tfvisualizer

# Environment variables
DB_HOST=postgres.tfvisualizer.svc.cluster.local
DB_PORT=5432
DB_NAME=tfvisualizer
DB_USER=tfuser
DB_PASSWORD=<from secret>
```

**Redis:**
```bash
# Connection string
redis://:PASSWORD@redis.tfvisualizer.svc.cluster.local:6379

# Environment variables
REDIS_HOST=redis.tfvisualizer.svc.cluster.local
REDIS_PORT=6379
REDIS_PASSWORD=<from secret>
```

### From Outside Cluster (kubectl port-forward)

**PostgreSQL:**
```bash
# Forward port
kubectl port-forward svc/postgres 5432:5432 -n tfvisualizer

# Connect
psql -h localhost -U tfuser -d tfvisualizer
```

**Redis:**
```bash
# Forward port
kubectl port-forward svc/redis 6379:6379 -n tfvisualizer

# Connect
redis-cli -h localhost -a PASSWORD
```

---

## 💾 Data Persistence

### Persistent Volume Claims

Both databases use StatefulSet volumeClaimTemplates with DigitalOcean Block Storage:

**PostgreSQL PVC:**
- Size: 20Gi
- StorageClass: do-block-storage
- Access Mode: ReadWriteOnce
- Mount: /var/lib/postgresql/data

**Redis PVC:**
- Size: 5Gi
- StorageClass: do-block-storage
- Access Mode: ReadWriteOnce
- Mount: /data

### Check PVCs

```bash
# List persistent volume claims
kubectl get pvc -n tfvisualizer

# Check volume details
kubectl describe pvc postgres-storage-postgres-0 -n tfvisualizer
kubectl describe pvc redis-storage-redis-0 -n tfvisualizer
```

---

## 🔄 Backup & Recovery

### Manual PostgreSQL Backup

**Backup:**
```bash
# Exec into pod
kubectl exec -it postgres-0 -n tfvisualizer -- bash

# Create backup
pg_dump -U tfuser tfvisualizer > /tmp/backup.sql

# Copy from pod
kubectl cp tfvisualizer/postgres-0:/tmp/backup.sql ./backup-$(date +%Y%m%d).sql
```

**Automated Backup CronJob:**
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
  namespace: tfvisualizer
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:15-alpine
            command:
            - /bin/sh
            - -c
            - |
              PGPASSWORD=$POSTGRES_PASSWORD pg_dump -h postgres -U tfuser tfvisualizer | \
              gzip > /backups/backup-$(date +%Y%m%d-%H%M%S).sql.gz
            env:
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: database-credentials
                  key: postgres-password
            volumeMounts:
            - name: backups
              mountPath: /backups
          volumes:
          - name: backups
            persistentVolumeClaim:
              claimName: postgres-backups
          restartPolicy: OnFailure
```

### PostgreSQL Restore

```bash
# Copy backup to pod
kubectl cp ./backup.sql tfvisualizer/postgres-0:/tmp/backup.sql

# Exec into pod
kubectl exec -it postgres-0 -n tfvisualizer -- bash

# Restore
psql -U tfuser tfvisualizer < /tmp/backup.sql
```

### Redis Backup

Redis uses AOF (Append Only File) persistence, automatically saved to the persistent volume.

**Manual snapshot:**
```bash
# Exec into pod
kubectl exec -it redis-0 -n tfvisualizer -- redis-cli -a PASSWORD

# Trigger save
BGSAVE

# Copy dump file
kubectl cp tfvisualizer/redis-0:/data/dump.rdb ./redis-backup-$(date +%Y%m%d).rdb
```

---

## 🔍 Monitoring & Debugging

### View Logs

**PostgreSQL:**
```bash
# View logs
kubectl logs -f postgres-0 -n tfvisualizer

# View last 100 lines
kubectl logs postgres-0 -n tfvisualizer --tail=100
```

**Redis:**
```bash
# View logs
kubectl logs -f redis-0 -n tfvisualizer

# View last 100 lines
kubectl logs redis-0 -n tfvisualizer --tail=100
```

### Database Shell Access

**PostgreSQL:**
```bash
# Connect to database
kubectl exec -it postgres-0 -n tfvisualizer -- psql -U tfuser -d tfvisualizer

# Run SQL
\dt                    # List tables
\d users              # Describe table
SELECT * FROM users;  # Query
```

**Redis:**
```bash
# Connect to Redis
kubectl exec -it redis-0 -n tfvisualizer -- redis-cli -a PASSWORD

# Run commands
KEYS *               # List keys
GET key              # Get value
INFO                 # Server info
```

### Check Database Status

**PostgreSQL:**
```bash
# Check if ready
kubectl exec postgres-0 -n tfvisualizer -- pg_isready -U tfuser

# Check connections
kubectl exec postgres-0 -n tfvisualizer -- \
  psql -U tfuser -d tfvisualizer -c "SELECT count(*) FROM pg_stat_activity;"

# Check database size
kubectl exec postgres-0 -n tfvisualizer -- \
  psql -U tfuser -d tfvisualizer -c "SELECT pg_size_pretty(pg_database_size('tfvisualizer'));"
```

**Redis:**
```bash
# Check if ready
kubectl exec redis-0 -n tfvisualizer -- redis-cli ping

# Check memory usage
kubectl exec redis-0 -n tfvisualizer -- redis-cli -a PASSWORD INFO memory

# Check connected clients
kubectl exec redis-0 -n tfvisualizer -- redis-cli -a PASSWORD INFO clients
```

---

## 🛠️ Maintenance Operations

### Restart Databases

**PostgreSQL:**
```bash
# Delete pod (will be recreated by StatefulSet)
kubectl delete pod postgres-0 -n tfvisualizer

# Watch restart
kubectl get pods -n tfvisualizer -w
```

**Redis:**
```bash
# Delete pod (will be recreated by StatefulSet)
kubectl delete pod redis-0 -n tfvisualizer

# Watch restart
kubectl get pods -n tfvisualizer -w
```

### Update Database Passwords

```bash
# Edit secret
kubectl edit secret database-credentials -n tfvisualizer

# Update postgres-password and redis-password (base64 encoded)
# Example: echo -n "new-password" | base64

# Restart databases to pick up new passwords
kubectl rollout restart statefulset postgres -n tfvisualizer
kubectl rollout restart statefulset redis -n tfvisualizer

# Update application secret
kubectl edit secret tfvisualizer-config -n tfvisualizer

# Restart application
kubectl rollout restart deployment tfvisualizer-app -n tfvisualizer
```

### Scale Storage

**Expand PostgreSQL volume:**
```bash
# Edit PVC
kubectl edit pvc postgres-storage-postgres-0 -n tfvisualizer

# Change storage request (e.g., 20Gi -> 50Gi)
# Note: Can only increase, not decrease

# Restart pod to apply
kubectl delete pod postgres-0 -n tfvisualizer
```

**Expand Redis volume:**
```bash
# Edit PVC
kubectl edit pvc redis-storage-redis-0 -n tfvisualizer

# Change storage request
# Restart pod
kubectl delete pod redis-0 -n tfvisualizer
```

---

## 🚨 Troubleshooting

### PostgreSQL Won't Start

**Check logs:**
```bash
kubectl logs postgres-0 -n tfvisualizer
```

**Common issues:**
- Permission denied on PGDATA: Check volume permissions
- Password authentication failed: Verify secret
- Port already in use: Check for conflicting services

**Fix permission issues:**
```bash
kubectl exec postgres-0 -n tfvisualizer -- chown -R postgres:postgres /var/lib/postgresql/data
```

### Redis Won't Start

**Check logs:**
```bash
kubectl logs redis-0 -n tfvisualizer
```

**Common issues:**
- AOF file corrupted: Use redis-check-aof
- Out of memory: Adjust maxmemory settings
- Password mismatch: Verify secret

### Application Can't Connect

**Test connectivity:**
```bash
# From another pod
kubectl run -it --rm debug --image=postgres:15-alpine --restart=Never -n tfvisualizer -- sh

# Test PostgreSQL
psql -h postgres.tfvisualizer.svc.cluster.local -U tfuser -d tfvisualizer

# Test Redis
redis-cli -h redis.tfvisualizer.svc.cluster.local -a PASSWORD ping
```

### Data Corruption

**PostgreSQL:**
```bash
# Check for corruption
kubectl exec postgres-0 -n tfvisualizer -- \
  psql -U tfuser -d tfvisualizer -c "SELECT * FROM pg_stat_database WHERE datname = 'tfvisualizer';"

# Restore from backup
kubectl cp ./backup.sql tfvisualizer/postgres-0:/tmp/backup.sql
kubectl exec -it postgres-0 -n tfvisualizer -- psql -U tfuser tfvisualizer < /tmp/backup.sql
```

**Redis:**
```bash
# Check AOF
kubectl exec redis-0 -n tfvisualizer -- redis-check-aof /data/appendonly.aof

# Fix AOF
kubectl exec redis-0 -n tfvisualizer -- redis-check-aof --fix /data/appendonly.aof
```

---

## 📈 Performance Tuning

### PostgreSQL Optimization

**Connection pooling:**
```sql
# Check current connections
SELECT count(*) FROM pg_stat_activity;

# Adjust max_connections
ALTER SYSTEM SET max_connections = 200;
SELECT pg_reload_conf();
```

**Vacuum and analyze:**
```bash
kubectl exec postgres-0 -n tfvisualizer -- \
  psql -U tfuser -d tfvisualizer -c "VACUUM ANALYZE;"
```

### Redis Optimization

**Adjust maxmemory:**
```bash
# Edit StatefulSet
kubectl edit statefulset redis -n tfvisualizer

# Change maxmemory in command args
# Restart pod
kubectl delete pod redis-0 -n tfvisualizer
```

---

## 🔗 Migration from Managed Databases

If migrating from DigitalOcean managed databases:

**1. Backup existing data:**
```bash
# PostgreSQL
pg_dump -h old-db-host -U tfuser tfvisualizer > migration-backup.sql

# Redis
redis-cli -h old-redis-host BGSAVE
redis-cli -h old-redis-host --rdb ./redis-migration.rdb
```

**2. Deploy new databases on DOKS:**
```bash
kubectl apply -f postgres.yaml
kubectl apply -f redis.yaml
```

**3. Restore data:**
```bash
# PostgreSQL
kubectl cp migration-backup.sql tfvisualizer/postgres-0:/tmp/
kubectl exec postgres-0 -n tfvisualizer -- psql -U tfuser tfvisualizer < /tmp/migration-backup.sql

# Redis
kubectl cp redis-migration.rdb tfvisualizer/redis-0:/data/dump.rdb
kubectl delete pod redis-0 -n tfvisualizer  # Restart to load
```

**4. Update application configuration:**
```bash
# Edit secrets with new connection strings
kubectl edit secret tfvisualizer-config -n tfvisualizer

# Restart application
kubectl rollout restart deployment tfvisualizer-app -n tfvisualizer
```

**5. Verify and cleanup:**
```bash
# Test application
curl http://app-url/health

# Remove old managed databases from DigitalOcean console
```

---

## 📚 Additional Resources

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Redis Documentation](https://redis.io/documentation)
- [Kubernetes StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [DigitalOcean Block Storage](https://docs.digitalocean.com/products/kubernetes/how-to/add-volumes/)

---

**Databases running on DOKS for cost-effective, consolidated infrastructure**
