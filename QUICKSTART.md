# TFVisualizer - Quick Start Guide

Get TFVisualizer running in 5 minutes!

## 🚀 Option 1: Docker Compose (Recommended)

### Prerequisites
- Docker Desktop installed
- Stripe account (for payments)

### Steps

1. **Clone and navigate**
```bash
cd tfvisualizer
```

2. **Configure environment**
```bash
cp .env.example .env
# Edit .env with your Stripe keys
```

3. **Start all services**
```bash
docker-compose up -d
```

4. **Access the application**
- Landing page: http://localhost
- Editor: http://localhost/editor
- Login: http://localhost/login

That's it! 🎉

---

## 🐍 Option 2: Local Python Development

### Prerequisites
- Python 3.11+
- PostgreSQL 15+
- Redis 7+

### Steps

1. **Create virtual environment**
```bash
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
```

2. **Install dependencies**
```bash
pip install -r requirements.txt
```

3. **Set up environment variables**
```bash
cp .env.example .env
# Edit .env with your configuration
```

4. **Initialize database**
```bash
# Make sure PostgreSQL is running
flask db init
flask db migrate -m "Initial migration"
flask db upgrade
```

5. **Start the server**
```bash
# Note: Port 80 requires sudo on Linux/Mac
sudo python run.py
```

Or use Flask directly:
```bash
sudo flask run --host=0.0.0.0 --port=80
```

For development without sudo, use a different port:
```bash
PORT=8080 python run.py
```

6. **Access the application**
- Landing page: http://localhost
- Editor: http://localhost/editor

---

## 🔑 Stripe Setup

### Get Your Stripe Keys

1. Sign up at https://stripe.com
2. Get API keys from https://dashboard.stripe.com/apikeys
3. Add to `.env`:
```bash
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PUBLISHABLE_KEY=pk_test_...
```

### Create Pro Product ($4.99/month)

1. Go to https://dashboard.stripe.com/products
2. Click "Add product"
3. Set:
   - Name: "TFVisualizer Pro"
   - Price: $4.99/month (recurring)
4. Copy the Price ID and add to `.env`:
```bash
STRIPE_PRICE_ID_PRO=price_...
```

### Set Up Webhook

1. Go to https://dashboard.stripe.com/webhooks
2. Click "Add endpoint"
3. URL: `https://yourdomain.com/api/webhooks/stripe`
4. Select events:
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `payment_intent.succeeded`
   - `payment_intent.payment_failed`
5. Copy webhook secret and add to `.env`:
```bash
STRIPE_WEBHOOK_SECRET=whsec_...
```

---

## 📊 Database Setup

### Using PostgreSQL (Recommended)

```bash
# Install PostgreSQL (Ubuntu/Debian)
sudo apt-get install postgresql postgresql-contrib

# Create database
sudo -u postgres createdb tfvisualizer

# Create user
sudo -u postgres createuser tfuser

# Set password and grant privileges
sudo -u postgres psql
postgres=# ALTER USER tfuser WITH PASSWORD 'your_password';
postgres=# GRANT ALL PRIVILEGES ON DATABASE tfvisualizer TO tfuser;
postgres=# \q
```

Update `.env`:
```bash
DATABASE_URL=postgresql://tfuser:your_password@localhost:5432/tfvisualizer
```

### Using Redis

```bash
# Install Redis (Ubuntu/Debian)
sudo apt-get install redis-server

# Start Redis
sudo systemctl start redis-server

# Test connection
redis-cli ping
# Should return: PONG
```

---

## 🧪 Testing the Application

### Test Registration
```bash
curl -X POST http://localhost/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test User",
    "email": "test@example.com",
    "password": "password123"
  }'
```

### Test Login
```bash
curl -X POST http://localhost/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'
```

### Test Subscription (requires authentication)
```bash
curl -X POST http://localhost/api/subscription/create-checkout-session \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json"
```

---

## 🔍 Health Check

```bash
curl http://localhost/health
```

Should return:
```json
{
  "status": "healthy",
  "database": "connected",
  "redis": "connected"
}
```

---

## 🎨 Using the Visual Editor

1. Go to http://localhost/editor
2. Drag AWS resources from the left panel
3. Drop them onto the canvas
4. Click "Connect" to link resources
5. Click "Export" to generate Terraform code

---

## 💳 Testing Stripe Integration

### Test Credit Cards

Use these test cards in Stripe Checkout:

| Card Number | Description |
|------------|-------------|
| 4242 4242 4242 4242 | Successful payment |
| 4000 0000 0000 0002 | Declined payment |
| 4000 0027 6000 3184 | 3D Secure authentication |

- Any future expiration date
- Any 3-digit CVC
- Any ZIP code

---

## 🐛 Troubleshooting

### Port already in use
```bash
# Find process using port 80
sudo lsof -i :80

# Kill the process
sudo kill -9 <PID>

# Or use a different port for development
PORT=8080 python run.py
```

### Database connection error
```bash
# Check PostgreSQL is running
sudo systemctl status postgresql

# Check connection
psql -U tfuser -d tfvisualizer -h localhost
```

### Redis connection error
```bash
# Check Redis is running
sudo systemctl status redis-server

# Test connection
redis-cli ping
```

### Stripe webhook not working
- Use ngrok for local testing:
```bash
ngrok http 80
# Use the ngrok URL in Stripe webhook settings
```

---

## 📚 Next Steps

1. **Customize branding** - Edit `templates/index.html`
2. **Add features** - See `DESIGN.md` for architecture
3. **Deploy to production** - See deployment section in README.md
4. **Set up monitoring** - Configure logging and metrics
5. **Enable SSL** - Use Let's Encrypt with nginx

---

## 🆘 Need Help?

- **Documentation**: See `README.md` and `DESIGN.md`
- **Issues**: https://github.com/elliotechne/tfvisualizer/issues
- **Email**: support@tfvisualizer.com

---

Built with ❤️ using Python Flask + Stripe
