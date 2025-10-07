# Local Development Guide

Quick guide for running TFVisualizer locally with GHCR integration.

---

## 🚀 Quick Start

### Option 1: Docker (Recommended)

```bash
# Login to GHCR (for private images)
export CR_PAT=ghp_your_personal_access_token
echo $CR_PAT | docker login ghcr.io -u elliotechne --password-stdin

# Pull latest image
docker pull ghcr.io/elliotechne/tfvisualizer:latest

# Run with Docker Compose
docker-compose up -d

# Access application
open http://localhost
```

### Option 2: Local Python Environment

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Setup environment
cp .env.example .env
nano .env  # Edit with your configuration

# Run database migrations
flask db upgrade

# Start development server
flask run --host=0.0.0.0 --port=8080
```

---

## 🔨 Building Images Locally

### Build for Local Testing

```bash
# Build image
docker build -t tfvisualizer:local .

# Run locally
docker run -p 80:80 \
  -e DATABASE_URL=postgresql://user:pass@host:5432/tfvisualizer \
  -e REDIS_URL=redis://host:6379 \
  tfvisualizer:local
```

### Build and Push to GHCR

```bash
# Login to GHCR
export CR_PAT=ghp_your_personal_access_token
echo $CR_PAT | docker login ghcr.io -u elliotechne --password-stdin

# Build for multiple platforms
docker buildx create --use
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/elliotechne/tfvisualizer:latest \
  -t ghcr.io/elliotechne/tfvisualizer:dev \
  --push .

# Build for single platform (faster)
docker build -t ghcr.io/elliotechne/tfvisualizer:dev .
docker push ghcr.io/elliotechne/tfvisualizer:dev
```

---

## 🐳 Docker Compose Setup

### docker-compose.yml

```yaml
version: '3.8'

services:
  app:
    image: ghcr.io/elliotechne/tfvisualizer:latest
    # Or build locally:
    # build: .
    ports:
      - "80:80"
    environment:
      - FLASK_ENV=development
      - DATABASE_URL=postgresql://tfuser:tfpass@postgres:5432/tfvisualizer
      - REDIS_URL=redis://redis:6379
      - SECRET_KEY=dev-secret-key
      - JWT_SECRET=dev-jwt-secret
    depends_on:
      - postgres
      - redis
    networks:
      - tfvisualizer

  postgres:
    image: postgres:15-alpine
    environment:
      - POSTGRES_DB=tfvisualizer
      - POSTGRES_USER=tfuser
      - POSTGRES_PASSWORD=tfpass
    volumes:
      - postgres-data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    networks:
      - tfvisualizer

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data
    networks:
      - tfvisualizer

volumes:
  postgres-data:
  redis-data:

networks:
  tfvisualizer:
    driver: bridge
```

### Commands

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f app

# Stop services
docker-compose down

# Rebuild and restart
docker-compose up -d --build

# Clean everything
docker-compose down -v
```

---

## 🔧 Development Workflow

### 1. Make Changes

```bash
# Edit code
nano app/routes/projects.py

# Test locally
flask run --port=8080
```

### 2. Build and Test Docker Image

```bash
# Build locally
docker build -t tfvisualizer:test .

# Run container
docker run -p 80:80 --env-file .env tfvisualizer:test

# Test application
curl http://localhost/health
```

### 3. Push to Development Branch

```bash
git checkout -b feature/my-feature
git add .
git commit -m "Add new feature"
git push origin feature/my-feature
```

### 4. GitHub Actions Auto-Build

GitHub Actions automatically:
- Builds Docker image
- Pushes to `ghcr.io/elliotechne/tfvisualizer:feature-my-feature`
- Runs tests
- Scans for vulnerabilities

### 5. Test in Kubernetes (Optional)

```bash
# Get kubeconfig from Terraform output
cd terraform
terraform output -raw kubeconfig > kubeconfig.yaml
export KUBECONFIG=$(pwd)/kubeconfig.yaml

# Deploy feature branch
kubectl set image deployment/tfvisualizer-app \
  tfvisualizer=ghcr.io/elliotechne/tfvisualizer:feature-my-feature \
  -n tfvisualizer

# Watch deployment
kubectl rollout status deployment/tfvisualizer-app -n tfvisualizer

# Rollback when done testing
kubectl rollout undo deployment/tfvisualizer-app -n tfvisualizer
```

---

## 🧪 Testing

### Run Tests Locally

```bash
# Install test dependencies
pip install pytest pytest-cov

# Run tests
pytest tests/

# With coverage
pytest --cov=app tests/

# Generate HTML coverage report
pytest --cov=app --cov-report=html tests/
open htmlcov/index.html
```

### Test Docker Image

```bash
# Build test image
docker build -t tfvisualizer:test .

# Run tests in container
docker run --rm tfvisualizer:test pytest tests/

# Interactive shell for debugging
docker run -it --rm tfvisualizer:test /bin/sh
```

---

## 🔍 Debugging

### View Application Logs

```bash
# Docker Compose
docker-compose logs -f app

# Docker container
docker logs -f <container-id>

# Kubernetes
kubectl logs -f -l app=tfvisualizer -n tfvisualizer
```

### Shell Access

```bash
# Docker Compose
docker-compose exec app /bin/sh

# Docker container
docker exec -it <container-id> /bin/sh

# Kubernetes
kubectl exec -it <pod-name> -n tfvisualizer -- /bin/sh
```

### Database Access

```bash
# Connect to local PostgreSQL
docker-compose exec postgres psql -U tfuser -d tfvisualizer

# Kubernetes database
kubectl port-forward svc/postgres 5432:5432 -n tfvisualizer
psql -h localhost -U tfuser -d tfvisualizer
```

### Redis Access

```bash
# Connect to local Redis
docker-compose exec redis redis-cli

# Kubernetes Redis
kubectl port-forward svc/redis 6379:6379 -n tfvisualizer
redis-cli -h localhost
```

---

## 🌐 Environment Variables

### Required Variables

```bash
# Application
FLASK_ENV=development
PORT=80
SECRET_KEY=your-secret-key
JWT_SECRET=your-jwt-secret

# Database
DATABASE_URL=postgresql://user:pass@host:5432/tfvisualizer
DB_HOST=localhost
DB_PORT=5432
DB_NAME=tfvisualizer
DB_USER=tfuser
DB_PASSWORD=password

# Redis
REDIS_URL=redis://localhost:6379
REDIS_HOST=localhost
REDIS_PORT=6379

# Stripe
STRIPE_SECRET_KEY=sk_test_your_key
STRIPE_PUBLISHABLE_KEY=pk_test_your_key
STRIPE_WEBHOOK_SECRET=whsec_your_secret
STRIPE_PRICE_ID_PRO=price_your_id
```

### .env.example

```bash
cp .env.example .env
nano .env  # Edit with your values
```

---

## 🔗 Useful Links

- **Application**: http://localhost
- **API Docs**: http://localhost/api
- **Health Check**: http://localhost/health
- **GHCR Package**: https://github.com/elliotechne?tab=packages

---

## 💡 Tips

### Fast Iteration

```bash
# Skip Docker build, run directly
export FLASK_APP=app.main:create_app
export FLASK_ENV=development
flask run --reload --port=8080
```

### Hot Reload with Docker

```bash
# Mount code as volume for hot reload
docker run -p 80:80 \
  -v $(pwd)/app:/app/app \
  -e FLASK_ENV=development \
  --env-file .env \
  tfvisualizer:local
```

### Use Development Database

```bash
# SQLite for quick testing
export DATABASE_URL=sqlite:///dev.db
flask db upgrade
flask run
```

### Skip Redis for Testing

```bash
# App gracefully handles missing Redis
unset REDIS_URL
flask run
```

---

## 📚 Additional Resources

- [Flask Documentation](https://flask.palletsprojects.com/)
- [Docker Documentation](https://docs.docker.com/)
- [GHCR Setup Guide](GHCR_SETUP.md)
- [Kubernetes Deployment](KUBERNETES_DEPLOYMENT.md)

---

**Happy coding! 🚀**
