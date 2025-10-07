# Docker Build and Run Guide

Complete guide for building and running TFVisualizer with Docker (without docker-compose).

---

## 🐳 Quick Start (Standalone Docker)

### 1. Build the Image

```bash
docker build -t tfvisualizer:latest .
```

### 2. Run PostgreSQL

```bash
docker run -d \
  --name tfvisualizer-postgres \
  -e POSTGRES_DB=tfvisualizer \
  -e POSTGRES_USER=tfuser \
  -e POSTGRES_PASSWORD=secure_password_here \
  -p 5432:5432 \
  postgres:15-alpine
```

### 3. Run Redis

```bash
docker run -d \
  --name tfvisualizer-redis \
  -p 6379:6379 \
  redis:7-alpine
```

### 4. Run the Application

```bash
docker run -d \
  --name tfvisualizer-app \
  -p 80:80 \
  -e DATABASE_URL=postgresql://tfuser:secure_password_here@host.docker.internal:5432/tfvisualizer \
  -e REDIS_URL=redis://host.docker.internal:6379 \
  -e DB_HOST=host.docker.internal \
  -e DB_PORT=5432 \
  -e DB_NAME=tfvisualizer \
  -e DB_USER=tfuser \
  -e DB_PASSWORD=secure_password_here \
  -e FLASK_ENV=production \
  -e SECRET_KEY=your_secret_key_here \
  -e JWT_SECRET=your_jwt_secret_here \
  -e STRIPE_SECRET_KEY=sk_test_your_key \
  -e STRIPE_PUBLISHABLE_KEY=pk_test_your_key \
  -e STRIPE_WEBHOOK_SECRET=whsec_your_secret \
  -e STRIPE_PRICE_ID_PRO=price_your_price_id \
  tfvisualizer:latest
```

### 5. Access the Application

```bash
# Landing page
open http://localhost

# Health check
curl http://localhost/health
```

---

## 🌐 Using Docker Network (Recommended)

For better container communication, use a Docker network:

```bash
# 1. Create network
docker network create tfvisualizer-network

# 2. Run PostgreSQL
docker run -d \
  --name tfvisualizer-postgres \
  --network tfvisualizer-network \
  -e POSTGRES_DB=tfvisualizer \
  -e POSTGRES_USER=tfuser \
  -e POSTGRES_PASSWORD=secure_password_here \
  -p 5432:5432 \
  postgres:15-alpine

# 3. Run Redis
docker run -d \
  --name tfvisualizer-redis \
  --network tfvisualizer-network \
  -p 6379:6379 \
  redis:7-alpine

# 4. Run Application
docker run -d \
  --name tfvisualizer-app \
  --network tfvisualizer-network \
  -p 80:80 \
  -e DATABASE_URL=postgresql://tfuser:secure_password_here@tfvisualizer-postgres:5432/tfvisualizer \
  -e REDIS_URL=redis://tfvisualizer-redis:6379 \
  -e DB_HOST=tfvisualizer-postgres \
  -e DB_PORT=5432 \
  -e DB_NAME=tfvisualizer \
  -e DB_USER=tfuser \
  -e DB_PASSWORD=secure_password_here \
  -e FLASK_ENV=production \
  -e SECRET_KEY=your_secret_key_here \
  -e JWT_SECRET=your_jwt_secret_here \
  -e STRIPE_SECRET_KEY=sk_test_your_key \
  -e STRIPE_PUBLISHABLE_KEY=pk_test_your_key \
  -e STRIPE_WEBHOOK_SECRET=whsec_your_secret \
  -e STRIPE_PRICE_ID_PRO=price_your_price_id \
  tfvisualizer:latest
```

---

## 📋 Environment Variables Reference

### Required Variables

```bash
# Database
DATABASE_URL=postgresql://tfuser:password@host:5432/tfvisualizer
DB_HOST=postgres_host
DB_PORT=5432
DB_NAME=tfvisualizer
DB_USER=tfuser
DB_PASSWORD=your_password

# Redis
REDIS_URL=redis://redis_host:6379

# Security
SECRET_KEY=your_secret_key_min_32_chars
JWT_SECRET=your_jwt_secret_min_32_chars

# Stripe (for payments)
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_PRICE_ID_PRO=price_...
```

### Optional Variables

```bash
# Application
FLASK_ENV=production
PORT=80
LOG_LEVEL=INFO

# AWS (for S3 storage)
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_secret
S3_BUCKET_NAME=tfvisualizer-files

# Email
MAIL_SERVER=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=your_email@gmail.com
MAIL_PASSWORD=your_app_password
```

---

## 🔧 Build Options

### Build with Custom Tag

```bash
docker build -t tfvisualizer:v1.0.0 .
```

### Build with Build Args

```bash
docker build \
  --build-arg PYTHON_VERSION=3.11 \
  -t tfvisualizer:latest .
```

### Build for Different Platform

```bash
# For ARM64 (Apple Silicon)
docker build --platform linux/arm64 -t tfvisualizer:latest .

# For AMD64 (Intel/AMD)
docker build --platform linux/amd64 -t tfvisualizer:latest .

# Multi-platform
docker buildx build --platform linux/amd64,linux/arm64 -t tfvisualizer:latest .
```

---

## 🔍 Verify the Build

```bash
# Check image size
docker images tfvisualizer:latest

# Inspect image
docker inspect tfvisualizer:latest

# Check layers
docker history tfvisualizer:latest
```

---

## 🚀 Production Deployment

### Using Environment File

Create `.env.production`:
```bash
DATABASE_URL=postgresql://tfuser:password@db-host:5432/tfvisualizer
REDIS_URL=redis://redis-host:6379
SECRET_KEY=production_secret_key
JWT_SECRET=production_jwt_secret
STRIPE_SECRET_KEY=sk_live_...
STRIPE_PUBLISHABLE_KEY=pk_live_...
FLASK_ENV=production
```

Run with env file:
```bash
docker run -d \
  --name tfvisualizer-app \
  -p 80:80 \
  --env-file .env.production \
  tfvisualizer:latest
```

---

## 📊 Monitoring & Logs

### View Logs

```bash
# View all logs
docker logs tfvisualizer-app

# Follow logs
docker logs -f tfvisualizer-app

# Last 100 lines
docker logs --tail 100 tfvisualizer-app

# Logs with timestamps
docker logs -t tfvisualizer-app
```

### Check Container Status

```bash
# List running containers
docker ps

# Check container health
docker inspect --format='{{.State.Health.Status}}' tfvisualizer-app

# Check resource usage
docker stats tfvisualizer-app
```

---

## 🛠️ Troubleshooting

### PostgreSQL Connection Issues

The container includes a `wait-for-db.sh` script that:
1. Waits up to 60 seconds for PostgreSQL port to be open
2. Verifies PostgreSQL is accepting connections
3. Exits with error if database is not ready

Check logs:
```bash
docker logs tfvisualizer-app | grep PostgreSQL
```

### Container Won't Start

```bash
# Check container logs
docker logs tfvisualizer-app

# Run interactively for debugging
docker run -it --rm \
  -e DATABASE_URL=postgresql://tfuser:password@host:5432/tfvisualizer \
  tfvisualizer:latest /bin/sh
```

### Test Database Connection

```bash
# From host
docker exec tfvisualizer-app \
  psql -h tfvisualizer-postgres -U tfuser -d tfvisualizer -c "SELECT 1"

# Interactive shell
docker exec -it tfvisualizer-app /bin/sh
```

---

## 🧹 Cleanup

### Stop and Remove Containers

```bash
docker stop tfvisualizer-app tfvisualizer-postgres tfvisualizer-redis
docker rm tfvisualizer-app tfvisualizer-postgres tfvisualizer-redis
```

### Remove Network

```bash
docker network rm tfvisualizer-network
```

### Remove Images

```bash
docker rmi tfvisualizer:latest
```

### Clean Everything

```bash
# WARNING: This removes ALL unused containers, networks, and images
docker system prune -a
```

---

## 🔐 Security Best Practices

1. **Never use default passwords in production**
2. **Use Docker secrets for sensitive data**
3. **Run containers with read-only filesystem where possible**
4. **Use specific image tags, not `latest`**
5. **Scan images for vulnerabilities**

```bash
# Scan for vulnerabilities
docker scan tfvisualizer:latest
```

---

## 📦 Export/Import Image

### Save Image to File

```bash
docker save tfvisualizer:latest > tfvisualizer.tar
# Or compressed
docker save tfvisualizer:latest | gzip > tfvisualizer.tar.gz
```

### Load Image from File

```bash
docker load < tfvisualizer.tar
# Or compressed
gunzip -c tfvisualizer.tar.gz | docker load
```

---

## 🎯 Quick Reference

```bash
# Build
docker build -t tfvisualizer:latest .

# Run (with network)
docker network create tfvisualizer-network
docker run -d --name postgres --network tfvisualizer-network -e POSTGRES_PASSWORD=pass postgres:15-alpine
docker run -d --name redis --network tfvisualizer-network redis:7-alpine
docker run -d --name app --network tfvisualizer-network -p 80:80 -e DATABASE_URL=postgresql://postgres:pass@postgres:5432/tfvisualizer tfvisualizer:latest

# Check
curl http://localhost/health

# Logs
docker logs -f app

# Stop
docker stop app postgres redis

# Clean
docker rm app postgres redis
docker network rm tfvisualizer-network
```

---

**Built with Alpine Linux 3.22.1 for minimal image size (~200MB)**
