# TFVisualizer.com - Comprehensive Design Document

## 🎯 Vision
TFVisualizer.com is a modern web application for visually designing, managing, and optimizing Terraform infrastructure with real-time cost estimation, module support, and seamless import/export capabilities.

---

## 🏗️ Architecture Overview

### Technology Stack

#### Frontend
- **Framework**: React 18+ with TypeScript
- **Visualization**: React Flow for graph rendering
- **State Management**: Zustand
- **UI Components**: Tailwind CSS + Headless UI
- **Code Editor**: Monaco Editor (VS Code engine)
- **Build Tool**: Vite
- **Testing**: Vitest + React Testing Library

#### Backend
- **Runtime**: Python 3.11+
- **Framework**: Flask or FastAPI
- **ORM**: SQLAlchemy for database operations
- **Terraform Parsing**: python-hcl2 parser
- **API**: RESTful API with Flask-RESTful or FastAPI
- **Validation**: Pydantic for request/response validation
- **Payments**: Stripe Python SDK for subscription management
- **Auth**: Flask-JWT-Extended or FastAPI JWT

#### Database
- **Primary**: PostgreSQL 15+ (user data, projects, saved designs)
- **Cache/Session**: Redis (session management, real-time state)
- **Object Storage**: AWS S3 (storing .tf files, exports)

#### Infrastructure
- **Cloud Provider**: AWS
- **Container Orchestration**: Amazon EKS
- **CI/CD**: GitHub Actions
- **IaC**: Terraform for provisioning infrastructure
- **Monitoring**: Prometheus + Grafana, CloudWatch
- **Logging**: CloudWatch Logs

---

## 💳 Subscription Model

### Pricing Tiers

#### Free Tier
- **Price**: $0/month
- **Features**:
  - Up to 3 projects
  - Basic AWS resources
  - Import/Export .tf files
  - Cost estimation
  - Community support

#### Pro Tier
- **Price**: $4.99/month
- **Features**:
  - Unlimited projects
  - All cloud providers (AWS, Azure, GCP)
  - Module support
  - Data sources
  - Real-time collaboration
  - Version history (30 days)
  - Priority support
  - Export to PNG/SVG
  - Private projects

### Stripe Integration
- **Stripe Checkout**: Hosted payment page
- **Stripe Customer Portal**: Self-service subscription management
- **Webhooks**: Handle subscription events (created, updated, cancelled)
- **Payment Methods**: Credit/debit cards, digital wallets
- **Billing**: Automatic monthly recurring billing
- **Invoicing**: Automated invoice generation and email

---

## 📦 Core Features

### 1. Visual Terraform Designer
- **Drag-and-drop interface** for adding AWS resources
- **Real-time graph visualization** showing resource dependencies
- **Smart connection system** with auto-detection of valid relationships
- **Resource categorization**: Compute, Database, Storage, Network
- **Module support**: Visual representation of Terraform modules
- **Data source integration**: Query existing infrastructure

### 2. Import/Export Functionality
- **Import existing .tf files** and auto-generate visual diagram
- **Export designs to .tf files** with proper formatting
- **Batch import/export** of multiple files
- **Git integration** for version control
- **Import from Terraform state files** (`.tfstate`)
- **Export to multiple formats**: HCL, JSON, YAML

### 3. Cost Estimation Engine
- **Real-time cost calculations** as resources are added
- **Provider-specific pricing**: AWS, Azure, GCP
- **Monthly and hourly estimates**
- **Cost breakdown by service**
- **Budget alerts and warnings**
- **Historical cost tracking**
- **Integration with AWS Pricing API**

### 4. Module Support
- **Terraform Registry integration** to browse and use public modules
- **Private module registry** support
- **Visual module composition**
- **Version management** for modules
- **Module input/output mapping**
- **Custom module creation**

### 5. Data Sources
- **Visual data source blocks** for referencing existing resources
- **Filter configuration UI**
- **Common data sources**: AMIs, VPCs, Availability Zones
- **Dynamic data source discovery**

### 6. Collaboration Features
- **Real-time collaborative editing** (similar to Figma)
- **User presence indicators**
- **Comment and annotation system**
- **Project sharing and permissions**
- **Version history and rollback**

### 7. Advanced Features
- **Terraform validation** (syntax checking)
- **Terraform plan preview** (dry-run)
- **Resource tagging and organization**
- **Search and filter resources**
- **Auto-layout algorithms** for clean diagrams
- **Export to PNG/SVG** for documentation
- **Terraform workspace support**

---

## 🗄️ Database Schema

### Users Table
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  name VARCHAR(255) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  avatar_url TEXT,
  stripe_customer_id VARCHAR(255) UNIQUE,
  subscription_tier VARCHAR(50) DEFAULT 'free',
  subscription_status VARCHAR(50) DEFAULT 'inactive',
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### Subscriptions Table
```sql
CREATE TABLE subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  stripe_subscription_id VARCHAR(255) UNIQUE NOT NULL,
  stripe_price_id VARCHAR(255) NOT NULL,
  status VARCHAR(50) NOT NULL,
  current_period_start TIMESTAMP NOT NULL,
  current_period_end TIMESTAMP NOT NULL,
  cancel_at_period_end BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### Payment History Table
```sql
CREATE TABLE payment_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  stripe_payment_intent_id VARCHAR(255) UNIQUE NOT NULL,
  amount DECIMAL(10, 2) NOT NULL,
  currency VARCHAR(3) DEFAULT 'usd',
  status VARCHAR(50) NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);
```

### Projects Table
```sql
CREATE TABLE projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  visibility VARCHAR(50) DEFAULT 'private',
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### Project Versions Table
```sql
CREATE TABLE project_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
  version_number INTEGER NOT NULL,
  resources JSONB NOT NULL,
  connections JSONB NOT NULL,
  positions JSONB NOT NULL,
  terraform_code TEXT,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMP DEFAULT NOW()
);
```

### Shared Projects Table
```sql
CREATE TABLE project_shares (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
  shared_with_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  permission VARCHAR(50) DEFAULT 'view',
  created_at TIMESTAMP DEFAULT NOW()
);
```

### Cost Estimates Table
```sql
CREATE TABLE cost_estimates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
  version_id UUID REFERENCES project_versions(id),
  total_monthly_cost DECIMAL(10, 2),
  breakdown JSONB,
  estimated_at TIMESTAMP DEFAULT NOW()
);
```

---

## 🔌 API Design

### Authentication Endpoints
```
POST   /api/auth/register
POST   /api/auth/login
POST   /api/auth/logout
GET    /api/auth/me
POST   /api/auth/refresh
```

### Subscription/Payment Endpoints
```
POST   /api/subscription/create-checkout-session
POST   /api/subscription/create-portal-session
GET    /api/subscription/status
POST   /api/subscription/cancel
POST   /api/webhooks/stripe
GET    /api/subscription/invoices
```

### Project Endpoints
```
GET    /api/projects
POST   /api/projects
GET    /api/projects/:id
PUT    /api/projects/:id
DELETE /api/projects/:id
GET    /api/projects/:id/versions
POST   /api/projects/:id/versions
```

### Terraform Operations
```
POST   /api/terraform/parse
POST   /api/terraform/generate
POST   /api/terraform/validate
POST   /api/terraform/plan
POST   /api/terraform/format
```

### Module Endpoints
```
GET    /api/modules/search
GET    /api/modules/:id
GET    /api/modules/:id/versions
```

### Cost Estimation
```
POST   /api/cost/estimate
GET    /api/cost/pricing/:provider
```

### Import/Export
```
POST   /api/import/terraform
POST   /api/import/tfstate
GET    /api/export/:projectId/hcl
GET    /api/export/:projectId/json
```

---

## 🎨 Frontend Architecture

### Component Structure
```
src/
├── components/
│   ├── Canvas/
│   │   ├── Canvas.tsx
│   │   ├── ResourceCard.tsx
│   │   ├── Connection.tsx
│   │   └── GridBackground.tsx
│   ├── Palette/
│   │   ├── ResourcePalette.tsx
│   │   ├── CategorySection.tsx
│   │   └── ResourceItem.tsx
│   ├── CodeEditor/
│   │   ├── CodePanel.tsx
│   │   ├── TerraformEditor.tsx
│   │   └── ExportDialog.tsx
│   ├── Modals/
│   │   ├── EditResourceModal.tsx
│   │   ├── ImportModal.tsx
│   │   └── ShareProjectModal.tsx
│   ├── Toolbar/
│   │   ├── MainToolbar.tsx
│   │   ├── ZoomControls.tsx
│   │   └── CostBadge.tsx
│   └── Layout/
│       ├── Header.tsx
│       ├── Sidebar.tsx
│       └── Footer.tsx
├── pages/
│   ├── Dashboard.tsx
│   ├── Editor.tsx
│   ├── Projects.tsx
│   └── Auth/
│       ├── Login.tsx
│       └── Register.tsx
├── stores/
│   ├── useCanvasStore.ts
│   ├── useProjectStore.ts
│   └── useAuthStore.ts
├── services/
│   ├── api.ts
│   ├── terraform.ts
│   ├── cost.ts
│   └── modules.ts
├── utils/
│   ├── parser.ts
│   ├── codegen.ts
│   ├── validation.ts
│   └── pricing.ts
└── types/
    ├── resources.ts
    ├── project.ts
    └── api.ts
```

---

## 🔧 Backend Architecture

```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py                    # Application entry point
│   ├── routes/
│   │   ├── __init__.py
│   │   ├── auth.py                # Authentication routes
│   │   ├── projects.py            # Project management
│   │   ├── terraform.py           # Terraform operations
│   │   ├── subscription.py        # Stripe subscription routes
│   │   └── webhooks.py            # Stripe webhooks
│   ├── models/
│   │   ├── __init__.py
│   │   ├── user.py                # User model
│   │   ├── project.py             # Project model
│   │   ├── subscription.py        # Subscription model
│   │   └── payment.py             # Payment history model
│   ├── schemas/
│   │   ├── __init__.py
│   │   ├── user.py                # User schemas (Pydantic)
│   │   ├── project.py             # Project schemas
│   │   └── subscription.py        # Subscription schemas
│   ├── services/
│   │   ├── __init__.py
│   │   ├── auth_service.py        # Authentication logic
│   │   ├── stripe_service.py      # Stripe integration
│   │   ├── terraform_service.py   # HCL parsing/generation
│   │   ├── cost_service.py        # Cost estimation
│   │   └── email_service.py       # Email notifications
│   ├── middleware/
│   │   ├── __init__.py
│   │   ├── auth.py                # JWT authentication
│   │   ├── subscription.py        # Subscription validation
│   │   └── error_handler.py       # Global error handling
│   ├── utils/
│   │   ├── __init__.py
│   │   ├── logger.py              # Logging configuration
│   │   ├── validators.py          # Input validation
│   │   └── pricing.py             # AWS pricing data
│   ├── config/
│   │   ├── __init__.py
│   │   ├── settings.py            # Application settings
│   │   ├── database.py            # Database configuration
│   │   └── stripe.py              # Stripe configuration
│   └── templates/
│       ├── emails/                # Email templates
│       └── index.html             # Serve landing page
├── migrations/                     # Alembic migrations
├── tests/
│   ├── __init__.py
│   ├── test_auth.py
│   ├── test_subscription.py
│   └── test_terraform.py
├── requirements.txt
├── requirements-dev.txt
└── pytest.ini
```

---

## 💰 Cost Estimation Implementation

### Pricing Data Sources
1. **AWS Pricing API**: Real-time pricing data
2. **Static pricing tables**: Fallback for common resources
3. **User-configurable pricing**: Custom rates

### Cost Calculation
```typescript
interface CostEstimate {
  resourceId: string;
  resourceType: string;
  monthlyCost: number;
  hourlyRate: number;
  breakdown: {
    compute?: number;
    storage?: number;
    network?: number;
  };
}
```

---

## 🔄 Terraform Parser Implementation

### HCL Parsing
```typescript
import { parse } from '@cdktf/hcl2json';

interface ParsedTerraform {
  resources: TerraformResource[];
  modules: TerraformModule[];
  dataSources: TerraformDataSource[];
  variables: TerraformVariable[];
  outputs: TerraformOutput[];
}
```

---

## 🚀 Deployment Architecture

### Infrastructure Components
- **Frontend**: S3 + CloudFront
- **Backend API**: EKS (3+ replicas)
- **Database**: RDS PostgreSQL (Multi-AZ)
- **Redis**: ElastiCache Redis cluster
- **Object Storage**: S3

### Docker Configuration

#### Multi-stage Dockerfile
```dockerfile
# Frontend build stage
FROM node:20-alpine AS frontend-build
WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ ./
RUN npm run build

# Backend build stage
FROM node:20-alpine AS backend-build
WORKDIR /app/backend
COPY backend/package*.json ./
RUN npm ci
COPY backend/ ./
RUN npm run build

# Production stage
FROM node:20-alpine AS production
WORKDIR /app

# Install production dependencies
COPY backend/package*.json ./
RUN npm ci --only=production

# Copy built backend
COPY --from=backend-build /app/backend/dist ./dist

# Copy built frontend to serve statically
COPY --from=frontend-build /app/frontend/dist ./public

# Set environment variables
ENV NODE_ENV=production
ENV PORT=3000

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start application
CMD ["node", "dist/app.js"]
```

#### Docker Compose (Local Development)
```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: tfvisualizer
      POSTGRES_USER: tfuser
      POSTGRES_PASSWORD: tfpass
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

  app:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "3000:3000"
    environment:
      DATABASE_URL: postgresql://tfuser:tfpass@postgres:5432/tfvisualizer
      REDIS_URL: redis://redis:6379
      STRIPE_SECRET_KEY: ${STRIPE_SECRET_KEY}
      STRIPE_WEBHOOK_SECRET: ${STRIPE_WEBHOOK_SECRET}
      JWT_SECRET: ${JWT_SECRET}
    depends_on:
      - postgres
      - redis
    volumes:
      - ./backend:/app/backend
      - ./frontend:/app/frontend

volumes:
  postgres_data:
  redis_data:
```

### CI/CD Pipeline
```yaml
# .github/workflows/deploy.yml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '20'
      - run: npm install
      - run: npm test

  build-and-push:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      - uses: aws-actions/amazon-ecr-login@v1
      - name: Build and push Docker image
        run: |
          docker build -t tfvisualizer:${{ github.sha }} .
          docker tag tfvisualizer:${{ github.sha }} ${{ secrets.ECR_REGISTRY }}/tfvisualizer:${{ github.sha }}
          docker tag tfvisualizer:${{ github.sha }} ${{ secrets.ECR_REGISTRY }}/tfvisualizer:latest
          docker push ${{ secrets.ECR_REGISTRY }}/tfvisualizer:${{ github.sha }}
          docker push ${{ secrets.ECR_REGISTRY }}/tfvisualizer:latest

  deploy:
    needs: build-and-push
    runs-on: ubuntu-latest
    steps:
      - uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      - name: Update EKS deployment
        run: |
          aws eks update-kubeconfig --name tfvisualizer-cluster --region us-east-1
          kubectl set image deployment/tfvisualizer app=${{ secrets.ECR_REGISTRY }}/tfvisualizer:${{ github.sha }}
          kubectl rollout status deployment/tfvisualizer
```

---

## 🔒 Security

- **JWT-based authentication** with refresh tokens
- **OAuth integration**: GitHub, Google
- **Encryption at rest and in transit**
- **API rate limiting**
- **WAF**: AWS WAF for DDoS protection
- **Stripe webhook signature verification**
- **PCI DSS compliance** (via Stripe)
- **Secure subscription management**

---

## 📊 Monitoring

- **Application metrics**: Request latency, error rates
- **Infrastructure metrics**: CPU, memory, disk
- **Business metrics**: Active users, projects created, subscriptions
- **Revenue metrics**: MRR, churn rate, conversion rate
- **Stripe Dashboard**: Payment analytics
- **Alerting**: PagerDuty + Slack

---

## 🎯 MVP Roadmap

### Phase 1: Core (Weeks 1-4)
- Basic visual designer
- Core AWS resources
- Code generation
- Import/export

### Phase 2: Enhanced (Weeks 5-8)
- Module support
- Data sources
- Cost estimation
- User authentication
- Stripe integration
- Subscription management

### Phase 3: Advanced (Weeks 9-12)
- Real-time collaboration
- Terraform Registry integration
- Version history
- Advanced validation

### Phase 4: Polish (Weeks 13-16)
- Performance optimization
- Multi-cloud support
- Mobile responsive
- Documentation

---

## 💡 Future Enhancements

- AI-powered infrastructure suggestions
- Policy as Code integration (OPA)
- Drift detection
- Multi-region deployments
- Cost optimization recommendations
- Template library
- CLI tool

---

**Last Updated**: 2025-10-06
**Version**: 1.0.0
**Status**: Design Phase
