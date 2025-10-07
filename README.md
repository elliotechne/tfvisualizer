# TFVisualizer.com

Visual Terraform Infrastructure Designer with Stripe subscriptions

## 🎯 Overview

TFVisualizer is a Python Flask web application that allows users to visually design, manage, and optimize Terraform infrastructure. It features drag-and-drop interface design, real-time cost estimation, module support, and Stripe-powered subscriptions.

## ✨ Features

- **Visual Terraform Designer**: Drag-and-drop AWS resources onto a canvas
- **Real-time Cost Estimation**: See infrastructure costs as you build
- **Import/Export**: Import existing .tf files and export to Terraform code
- **Module Support**: Use Terraform Registry modules visually
- **Data Sources**: Query existing AWS infrastructure
- **Stripe Subscriptions**: $4.99/month Pro tier with unlimited projects

## 🏗️ Tech Stack

**Backend:**
- Python 3.11+
- Flask web framework
- SQLAlchemy ORM
- PostgreSQL database
- Redis for caching
- Stripe Python SDK
- python-hcl2 for Terraform parsing

**Frontend:**
- Vanilla JavaScript
- HTML5/CSS3
- Interactive canvas-based UI

**Infrastructure:**
- Docker & Docker Compose
- GitHub Container Registry (ghcr.io)
- DigitalOcean Kubernetes Service (DOKS)
- AWS S3-compatible (DigitalOcean Spaces)
- Gunicorn WSGI server

## 🚀 Quick Start

### Prerequisites

- Docker (for containerized deployment)
- OR Python 3.11+ with PostgreSQL and Redis (for local development)
- Stripe account (for payment processing)
- GitHub account (for container registry)

### Container Images

Docker images are hosted on GitHub Container Registry:

```bash
# Pull latest image
docker pull ghcr.io/elliotechne/tfvisualizer:latest

# Login for private images
echo $GITHUB_TOKEN | docker login ghcr.io -u your-username --password-stdin
```

See [GHCR_SETUP.md](GHCR_SETUP.md) for complete configuration guide.

### Option 1: Docker (Recommended)

1. **Build the image**
```bash
docker build -t tfvisualizer:latest .
```

2. **Run with Docker network**
```bash
# Create network
docker network create tfvisualizer-network

# Run PostgreSQL
docker run -d --name postgres --network tfvisualizer-network \
  -e POSTGRES_DB=tfvisualizer -e POSTGRES_USER=tfuser -e POSTGRES_PASSWORD=secure_pass \
  postgres:15-alpine

# Run Redis
docker run -d --name redis --network tfvisualizer-network redis:7-alpine

# Run Application
docker run -d --name tfvisualizer-app --network tfvisualizer-network -p 80:80 \
  -e DATABASE_URL=postgresql://tfuser:secure_pass@postgres:5432/tfvisualizer \
  -e REDIS_URL=redis://redis:6379 \
  -e DB_HOST=postgres -e DB_PORT=5432 -e DB_NAME=tfvisualizer \
  -e DB_USER=tfuser -e DB_PASSWORD=secure_pass \
  -e SECRET_KEY=change_this_in_production \
  -e JWT_SECRET=change_this_in_production \
  -e STRIPE_SECRET_KEY=sk_test_your_key \
  -e STRIPE_PUBLISHABLE_KEY=pk_test_your_key \
  tfvisualizer:latest
```

3. **Access the application**
- Landing page: http://localhost
- Visual editor: http://localhost/editor
- Health check: http://localhost/health

**See [DOCKER.md](DOCKER.md) for complete Docker documentation.**

### Option 2: Docker Compose

```bash
cp .env.example .env
# Edit .env with your configuration
docker-compose up -d
```

### Local Development (without Docker)

1. **Create virtual environment**
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. **Install dependencies**
```bash
pip install -r requirements.txt
```

3. **Set up database**
```bash
flask db upgrade
```

4. **Run development server**
```bash
# Note: Running on port 80 requires sudo on Linux/Mac
sudo flask run --host=0.0.0.0 --port=80

# Or run on a different port for development
PORT=8080 flask run --host=0.0.0.0 --port=8080
```

## 💳 Stripe Integration

### Setup

1. Create a Stripe account at https://stripe.com
2. Get your API keys from https://dashboard.stripe.com/apikeys
3. Create a Product and Price for $4.99/month recurring
4. Set up webhook endpoint: `https://yourdomain.com/api/webhooks/stripe`
5. Add webhook events:
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `payment_intent.succeeded`
   - `payment_intent.payment_failed`

### Environment Variables

```bash
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_PRICE_ID_PRO=price_...
```

## 🗄️ Database Schema

### Users
- Stores user accounts with authentication
- Tracks Stripe customer ID and subscription status

### Subscriptions
- Links to Stripe subscription IDs
- Tracks billing periods and cancellation status

### Projects
- User's Terraform infrastructure designs
- Supports versioning

### Payment History
- Records all payment transactions

## 📡 API Endpoints

### Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login
- `GET /api/auth/me` - Get current user

### Subscriptions
- `POST /api/subscription/create-checkout-session` - Start Pro subscription
- `POST /api/subscription/create-portal-session` - Manage subscription
- `GET /api/subscription/status` - Get subscription status
- `POST /api/subscription/cancel` - Cancel subscription

### Webhooks
- `POST /api/webhooks/stripe` - Stripe webhook handler

### Projects
- `GET /api/projects` - List projects
- `POST /api/projects` - Create project
- `GET /api/projects/:id` - Get project details

## 🔒 Security

- JWT-based authentication
- Password hashing with bcrypt
- Stripe webhook signature verification
- PCI DSS compliance via Stripe
- Non-root Docker containers
- Environment variable secrets

## 🧪 Testing

```bash
# Run tests
pytest

# Run with coverage
pytest --cov=app tests/

# Run specific test
pytest tests/test_subscription.py
```

## 📦 Deployment

### Recommended: Terraform

All infrastructure is defined as code using Terraform:

```bash
cd terraform
terraform init
terraform apply
```

This creates:
- ✅ DOKS Kubernetes cluster
- ✅ PostgreSQL and Redis (on DOKS)
- ✅ Application deployment with auto-scaling
- ✅ Load balancer with SSL
- ✅ DNS records
- ✅ Spaces bucket

See [KUBERNETES_DEPLOYMENT.md](KUBERNETES_DEPLOYMENT.md) for complete guide.

> 💡 **Note**: The `k8s/` folder contains YAML files for reference only. All resources are managed by Terraform. See [YAML_TO_TERRAFORM_MAPPING.md](YAML_TO_TERRAFORM_MAPPING.md) for details.

### Production Environment Variables

Ensure these are set in production:
- `FLASK_ENV=production`
- Strong `SECRET_KEY` and `JWT_SECRET`
- Production Stripe keys
- Database credentials
- AWS credentials for S3

### Docker Deployment

```bash
# Build production image
docker build -t tfvisualizer:latest .

# Run container
docker run -d \
  -p 80:80 \
  --env-file .env \
  tfvisualizer:latest
```

### Health Check

```bash
curl http://localhost/health
```

## 📊 Subscription Tiers

### Free Tier ($0/month)
- Up to 3 projects
- Basic AWS resources
- Import/Export .tf files
- Cost estimation
- Community support

### Pro Tier ($4.99/month)
- Unlimited projects
- All cloud providers
- Module support
- Real-time collaboration
- Version history
- Priority support
- Export to PNG/SVG

## 🛠️ Development

### Project Structure

```
tfvisualizer/
├── app/
│   ├── __init__.py
│   ├── main.py                      # Application entry point
│   ├── config/
│   │   └── settings.py              # Configuration
│   ├── routes/
│   │   ├── auth.py                  # Authentication routes
│   │   ├── pages.py                 # HTML page routes
│   │   ├── projects.py              # Project management
│   │   ├── subscription.py          # Stripe subscriptions
│   │   ├── terraform.py             # Terraform operations
│   │   └── webhooks.py              # Stripe webhooks
│   ├── models/
│   │   ├── user.py                  # User model
│   │   ├── subscription.py          # Subscription model
│   │   ├── payment.py               # Payment history
│   │   └── project.py               # Project model
│   ├── services/
│   │   └── stripe_service.py        # Stripe integration
│   ├── middleware/
│   │   └── error_handler.py         # Global error handling
│   └── utils/
│       └── logger.py                # Logging utilities
├── templates/
│   ├── index.html                   # Landing page
│   ├── editor.html                  # Visual Terraform editor
│   ├── login.html                   # Login page
│   └── register.html                # Registration page
├── static/                          # CSS, JS, images
├── migrations/                      # Database migrations
├── tests/                           # Test suite
├── Dockerfile
├── docker-compose.yml
├── requirements.txt
├── .env.example
├── DESIGN.md
└── README.md
```

### Adding a New Feature

1. Create database model in `app/models/`
2. Create service in `app/services/`
3. Create routes in `app/routes/`
4. Add tests in `tests/`
5. Update DESIGN.md

## 📝 License

MIT License - see LICENSE file

## 🤝 Contributing

Contributions welcome! Please read CONTRIBUTING.md first.

## 📧 Support

- Email: support@tfvisualizer.com
- GitHub Issues: https://github.com/elliotechne/tfvisualizer/issues
- Documentation: https://docs.tfvisualizer.com

## 🙏 Acknowledgments

- Stripe for payment processing
- Terraform for infrastructure as code
- Flask community
- AWS pricing data

---

Built with ❤️ for DevOps engineers
