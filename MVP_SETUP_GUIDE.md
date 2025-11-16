# 🚀 Echoelmusic MVP - Complete Setup Guide

**From Zero to Revenue in 3 Months!**

This guide will take you from setup to your first paying customer.

---

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Local Development Setup](#local-development-setup)
3. [Database Setup](#database-setup)
4. [Stripe Configuration](#stripe-configuration)
5. [Running the Application](#running-the-application)
6. [Deployment](#deployment)
7. [Testing](#testing)
8. [Troubleshooting](#troubleshooting)

---

## 🎯 Prerequisites

Before you begin, make sure you have:

- **Node.js 20+** ([Download](https://nodejs.org/))
- **PostgreSQL 15+** ([Download](https://www.postgresql.org/download/))
- **Git** ([Download](https://git-scm.com/downloads))
- **Stripe Account** ([Sign up](https://stripe.com))
- **AWS Account** (for S3) or **Cloudflare Account** (for R2)

Optional for local development:
- **Docker** ([Download](https://www.docker.com/)) - for easy local setup

---

## 🏗️ Local Development Setup

### 1. Clone the Repository

```bash
git clone https://github.com/vibrationalforce/Echoelmusic.git
cd Echoelmusic
```

### 2. Backend Setup

```bash
cd backend

# Install dependencies
npm install

# Copy environment variables
cp .env.example .env

# Edit .env with your configuration
nano .env  # or use your preferred editor
```

**Required environment variables:**

```env
# Database
DATABASE_URL="postgresql://user:password@localhost:5432/echoelmusic"

# JWT
JWT_SECRET="your-super-secret-jwt-key-change-this"
JWT_EXPIRES_IN="7d"

# Stripe
STRIPE_SECRET_KEY="sk_test_..."
STRIPE_WEBHOOK_SECRET="whsec_..."
STRIPE_PRICE_ID_PRO="price_..."
STRIPE_PRICE_ID_STUDIO="price_..."

# AWS S3 (or Cloudflare R2)
AWS_ACCESS_KEY_ID="your_access_key"
AWS_SECRET_ACCESS_KEY="your_secret_key"
AWS_REGION="eu-central-1"
S3_BUCKET_NAME="echoelmusic-projects"

# Frontend URL
FRONTEND_URL="http://localhost:3001"
```

### 3. Frontend Setup

```bash
cd ../frontend

# Install dependencies
npm install

# Copy environment variables
cp .env.example .env.local

# Edit .env.local
nano .env.local
```

**Required environment variables:**

```env
NEXT_PUBLIC_API_URL=http://localhost:3000
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_...
```

---

## 🗄️ Database Setup

### Option 1: Using Docker (Recommended)

```bash
# From project root
docker-compose up -d postgres

# Wait for PostgreSQL to be ready (check with)
docker-compose ps
```

### Option 2: Manual PostgreSQL Setup

```bash
# Create database
createdb echoelmusic

# Or using psql
psql -U postgres
CREATE DATABASE echoelmusic;
\q
```

### Run Prisma Migrations

```bash
cd backend

# Generate Prisma client
npm run prisma:generate

# Run migrations
npm run prisma:migrate

# (Optional) Open Prisma Studio to view database
npm run prisma:studio
```

---

## 💳 Stripe Configuration

### 1. Create Stripe Account

1. Go to [stripe.com](https://stripe.com)
2. Sign up for an account
3. Activate your account (test mode is fine for development)

### 2. Create Products and Prices

**In Stripe Dashboard:**

1. Go to **Products** → **Add Product**
2. Create two products:

**Product 1: Echoelmusic Pro**
- Name: `Echoelmusic Pro`
- Description: `Professional music production with unlimited projects`
- Price: `€29.00 EUR / month`
- Recurring: Monthly
- Copy the **Price ID** → Use as `STRIPE_PRICE_ID_PRO`

**Product 2: Echoelmusic Studio**
- Name: `Echoelmusic Studio`
- Description: `Studio tier with team features and API access`
- Price: `€99.00 EUR / month`
- Recurring: Monthly
- Copy the **Price ID** → Use as `STRIPE_PRICE_ID_STUDIO`

### 3. Get API Keys

1. Go to **Developers** → **API Keys**
2. Copy **Secret key** → Use as `STRIPE_SECRET_KEY`
3. Copy **Publishable key** → Use as `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY`

### 4. Set Up Webhooks (For Production)

1. Go to **Developers** → **Webhooks**
2. Add endpoint: `https://your-api-domain.com/api/payments/webhook`
3. Select events:
   - `checkout.session.completed`
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `invoice.payment_succeeded`
   - `invoice.payment_failed`
4. Copy **Signing secret** → Use as `STRIPE_WEBHOOK_SECRET`

**For local testing, use Stripe CLI:**

```bash
# Install Stripe CLI
brew install stripe/stripe-cli/stripe  # macOS
# or download from https://stripe.com/docs/stripe-cli

# Login to Stripe
stripe login

# Forward webhooks to local server
stripe listen --forward-to localhost:3000/api/payments/webhook
```

---

## ▶️ Running the Application

### Option 1: Using Docker Compose (Easiest)

```bash
# From project root
docker-compose up

# Backend will be at: http://localhost:3000
# Database will be at: localhost:5432
```

**Then run frontend separately:**

```bash
cd frontend
npm run dev

# Frontend will be at: http://localhost:3001
```

### Option 2: Manual Start

**Terminal 1 - Backend:**

```bash
cd backend
npm run dev
# Server running at http://localhost:3000
```

**Terminal 2 - Frontend:**

```bash
cd frontend
npm run dev
# Frontend running at http://localhost:3001
```

### Verify Everything Works

1. Open http://localhost:3001
2. Click "Sign up"
3. Create an account
4. You should see the dashboard
5. Click "Upgrade to Pro" to test Stripe checkout (use test card: `4242 4242 4242 4242`)

---

## 🌐 Deployment

### Deploy Backend to Railway

1. **Create Railway Account:** [railway.app](https://railway.app)

2. **Create New Project:**
   ```bash
   # Install Railway CLI
   npm install -g @railway/cli

   # Login
   railway login

   # Initialize
   cd backend
   railway init
   ```

3. **Add PostgreSQL:**
   - In Railway dashboard, click "New" → "Database" → "PostgreSQL"
   - Copy the `DATABASE_URL` connection string

4. **Set Environment Variables:**
   - Go to your service → "Variables"
   - Add all variables from `.env.example`
   - Use the Railway-provided `DATABASE_URL`

5. **Deploy:**
   ```bash
   railway up
   ```

6. **Get Backend URL:**
   - Railway will provide a URL like: `https://your-app.up.railway.app`

### Deploy Frontend to Vercel

1. **Create Vercel Account:** [vercel.com](https://vercel.com)

2. **Connect GitHub:**
   - Push your code to GitHub first

3. **Import Project:**
   - Go to Vercel Dashboard
   - Click "New Project"
   - Import your GitHub repository
   - Set **Root Directory** to `frontend`

4. **Environment Variables:**
   - Add `NEXT_PUBLIC_API_URL` → Your Railway backend URL
   - Add `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY`

5. **Deploy:**
   - Click "Deploy"
   - Vercel will build and deploy automatically

6. **Custom Domain (Optional):**
   - Go to Settings → Domains
   - Add your custom domain (e.g., `app.echoelmusic.com`)

---

## 🧪 Testing

### Test Authentication

```bash
# Register user
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test1234!","name":"Test User"}'

# Login
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test1234!"}'

# Save the returned token for next requests
```

### Test Protected Routes

```bash
# Get profile (replace TOKEN with your JWT)
curl -X GET http://localhost:3000/api/auth/profile \
  -H "Authorization: Bearer TOKEN"
```

### Test Stripe Checkout

1. Go to http://localhost:3001
2. Login
3. Click "Upgrade to Pro"
4. Use Stripe test card:
   - Card: `4242 4242 4242 4242`
   - Expiry: Any future date
   - CVC: Any 3 digits
   - ZIP: Any 5 digits

---

## 🔧 Troubleshooting

### Backend won't start

**Problem:** `Error: JWT_SECRET not configured`
**Solution:** Make sure `.env` file exists and has `JWT_SECRET` set

**Problem:** Database connection error
**Solution:** Check PostgreSQL is running and `DATABASE_URL` is correct

### Frontend won't connect to backend

**Problem:** CORS error in browser console
**Solution:** Check `FRONTEND_URL` in backend `.env` matches your frontend URL

### Prisma migration fails

**Problem:** `Migration failed`
**Solution:**
```bash
# Reset database (⚠️ DELETES ALL DATA)
npx prisma migrate reset

# Or create new migration
npx prisma migrate dev --name init
```

### Stripe webhook not working

**Problem:** Webhook returns 400 error
**Solution:** Make sure you're using Stripe CLI for local testing:
```bash
stripe listen --forward-to localhost:3000/api/payments/webhook
```

---

## 📊 API Endpoints Reference

### Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login user
- `GET /api/auth/profile` - Get user profile (requires auth)
- `PUT /api/auth/profile` - Update profile (requires auth)

### Payments
- `GET /api/payments/plans` - Get available plans
- `POST /api/payments/checkout` - Create checkout session (requires auth)
- `POST /api/payments/portal` - Create customer portal (requires auth)
- `POST /api/payments/webhook` - Stripe webhook endpoint

### Projects
- `GET /api/projects` - Get user's projects (requires auth)
- `POST /api/projects` - Create project (requires auth)
- `GET /api/projects/:id` - Get project by ID (requires auth)
- `POST /api/projects/upload` - Upload project data (requires auth)
- `DELETE /api/projects/:id` - Delete project (requires auth)

---

## 🎯 Next Steps

1. ✅ **Complete this setup guide**
2. 🧪 **Test all features locally**
3. 🚀 **Deploy to production (Railway + Vercel)**
4. 💰 **Activate Stripe live mode**
5. 📱 **Integrate Desktop DAW with cloud sync**
6. 🎉 **Launch beta and get first users!**

---

## 💡 Support

- **Issues:** [GitHub Issues](https://github.com/vibrationalforce/Echoelmusic/issues)
- **Documentation:** See `/docs` folder
- **Email:** support@echoelmusic.com

---

**Built with ❤️ by Echoelmusic Team**
**Let's make bio-reactive music accessible to everyone!** 🎵
