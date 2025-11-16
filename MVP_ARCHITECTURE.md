# 🏗️ Echoelmusic MVP Architecture

**Complete Technical Architecture for Platform MVP**

---

## 🎯 Overview

Echoelmusic platform consists of three main components:

1. **Backend API** (Node.js + Express + PostgreSQL)
2. **Frontend Dashboard** (Next.js + React + TailwindCSS)
3. **Desktop DAW** (C++ + JUCE) - Connects to backend via REST API

---

## 📐 System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     CLIENT LAYER                             │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌───────────────────┐    ┌────────────────────────────┐   │
│  │  Web Dashboard    │    │  Desktop DAW (C++/JUCE)    │   │
│  │  (Next.js)        │    │  - 80+ Effects             │   │
│  │  - User Management│    │  - Bio-Feedback            │   │
│  │  - Subscriptions  │    │  - Cloud Sync              │   │
│  │  - Project List   │    │  - Session Management      │   │
│  └───────┬───────────┘    └────────────┬───────────────┘   │
│          │                               │                   │
└──────────┼───────────────────────────────┼───────────────────┘
           │                               │
           │    HTTPS REST API             │
           │                               │
┌──────────▼───────────────────────────────▼───────────────────┐
│                     API LAYER                                 │
├───────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Express.js Backend (TypeScript)                      │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐           │   │
│  │  │   Auth   │  │ Payments │  │ Projects │           │   │
│  │  │  Module  │  │  Module  │  │  Module  │           │   │
│  │  └──────────┘  └──────────┘  └──────────┘           │   │
│  └──────────────────────────────────────────────────────┘   │
│          │                  │                │                │
└──────────┼──────────────────┼────────────────┼────────────────┘
           │                  │                │
           │                  │                │
┌──────────▼──────────────────▼────────────────▼────────────────┐
│                   DATA & SERVICES LAYER                        │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌───────────────┐  ┌───────────────┐  ┌────────────────┐    │
│  │  PostgreSQL   │  │  Stripe       │  │  AWS S3 / R2   │    │
│  │  Database     │  │  Payments     │  │  File Storage  │    │
│  │  - Users      │  │  - Checkout   │  │  - Projects    │    │
│  │  - Projects   │  │  - Webhooks   │  │  - Audio Files │    │
│  │  - Payments   │  │  - Portal     │  └────────────────┘    │
│  └───────────────┘  └───────────────┘                         │
└────────────────────────────────────────────────────────────────┘
```

---

## 🗂️ Backend Architecture

### Tech Stack

- **Runtime:** Node.js 20+
- **Framework:** Express.js
- **Language:** TypeScript
- **ORM:** Prisma
- **Database:** PostgreSQL 15+
- **Authentication:** JWT (jsonwebtoken)
- **Payments:** Stripe SDK
- **Storage:** AWS SDK (S3 or Cloudflare R2)
- **File Uploads:** Multer

### Directory Structure

```
backend/
├── src/
│   ├── index.ts                    # Main entry point
│   ├── auth/                       # Authentication module
│   │   ├── auth.service.ts         # Business logic
│   │   ├── auth.controller.ts      # HTTP handlers
│   │   └── auth.routes.ts          # Route definitions
│   ├── payments/                   # Payment module
│   │   ├── stripe.service.ts       # Stripe integration
│   │   ├── payment.controller.ts   # HTTP handlers
│   │   └── payment.routes.ts       # Route definitions
│   ├── projects/                   # Project module
│   │   ├── project.service.ts      # Business logic
│   │   ├── project.controller.ts   # HTTP handlers
│   │   ├── project.routes.ts       # Route definitions
│   │   └── storage.service.ts      # S3/R2 integration
│   ├── users/                      # User module
│   │   └── user.routes.ts          # Route definitions
│   ├── middleware/                 # Middleware
│   │   ├── auth.middleware.ts      # JWT verification
│   │   └── error.middleware.ts     # Error handling
│   └── utils/                      # Utilities
│       ├── jwt.utils.ts            # JWT helpers
│       └── password.utils.ts       # Password hashing
├── prisma/
│   └── schema.prisma               # Database schema
├── package.json
├── tsconfig.json
├── Dockerfile
└── railway.json                    # Railway deployment config
```

### Database Schema

```prisma
// Core Models

User
  - id: String (cuid)
  - email: String (unique)
  - password: String (bcrypt hashed)
  - name: String?
  - subscription: SubscriptionTier (FREE|PRO|STUDIO)
  - stripeCustomerId: String?
  - subscriptionId: String?
  - subscriptionStatus: SubscriptionStatus
  - trialEndsAt: DateTime?
  - isTrialActive: Boolean
  - projects: Project[]
  - payments: Payment[]

Project
  - id: String (cuid)
  - userId: String
  - title: String
  - description: String?
  - tempo: Float
  - platform: Platform (DESKTOP|IOS|WEB)
  - xmlDataUrl: String? (S3 URL)
  - audioFiles: AudioFile[]
  - version: Int
  - createdAt: DateTime
  - updatedAt: DateTime

AudioFile
  - id: String (cuid)
  - projectId: String
  - filename: String
  - s3Url: String
  - size: Int
  - duration: Float?
  - format: String

Payment
  - id: String (cuid)
  - userId: String
  - stripePaymentId: String
  - amount: Int (in cents)
  - currency: String
  - status: PaymentStatus
  - description: String?
  - createdAt: DateTime
```

---

## 🎨 Frontend Architecture

### Tech Stack

- **Framework:** Next.js 14
- **Language:** TypeScript
- **Styling:** TailwindCSS
- **HTTP Client:** Axios
- **State:** React Hooks (local state)
- **Payments:** @stripe/stripe-js

### Directory Structure

```
frontend/
├── src/
│   ├── pages/                     # Next.js pages
│   │   ├── _app.tsx               # App wrapper
│   │   ├── index.tsx              # Home (redirects)
│   │   ├── login.tsx              # Login page
│   │   ├── register.tsx           # Registration page
│   │   └── dashboard.tsx          # Main dashboard
│   ├── components/                # Reusable components
│   ├── lib/                       # Libraries
│   │   └── api.ts                 # API client
│   └── styles/                    # Styles
│       └── globals.css            # Global CSS + Tailwind
├── public/                        # Static assets
├── package.json
├── next.config.js
├── tailwind.config.js
└── vercel.json                    # Vercel deployment config
```

### Key Features

#### Authentication Flow

1. User visits site → Redirected to `/login`
2. User registers → JWT token stored in localStorage
3. Token automatically added to all API requests
4. Token expires → Auto redirect to login
5. User can logout → Token cleared

#### Dashboard Features

- **Subscription Management:**
  - Display current tier (Free/Pro/Studio)
  - Trial countdown
  - Upgrade button → Stripe Checkout
  - Manage subscription → Stripe Portal

- **Project Management:**
  - List all projects
  - Create new project
  - View project details
  - Delete project

- **Download Desktop App:**
  - Links to download Windows/macOS/Linux versions

---

## 🔐 Security Architecture

### Authentication

- **JWT Tokens:** 7-day expiration
- **Password Hashing:** bcrypt with 12 salt rounds
- **Password Requirements:**
  - Minimum 8 characters
  - At least 1 uppercase letter
  - At least 1 lowercase letter
  - At least 1 number

### API Security

- **Helmet.js:** HTTP security headers
- **CORS:** Restricted to frontend URL
- **Rate Limiting:** 100 requests per 15 minutes
- **Request Size Limit:** 50MB (for audio files)

### Data Security

- **S3 Files:** Private ACL (not publicly accessible)
- **Signed URLs:** 1-hour expiration for downloads
- **Database:** SSL connections required in production
- **Environment Variables:** Never committed to git

---

## 💰 Payment Flow

### Subscription Flow

1. **User clicks "Upgrade"**
   - Frontend calls `/api/payments/checkout`
   - Backend creates Stripe Checkout Session
   - Returns checkout URL

2. **User redirected to Stripe**
   - Enters payment details
   - Stripe processes payment

3. **Stripe sends webhook**
   - `checkout.session.completed` event
   - Backend updates user subscription tier
   - User can now access Pro features

4. **Recurring billing**
   - Stripe auto-charges monthly
   - Webhooks update subscription status
   - `invoice.payment_succeeded` → Active
   - `invoice.payment_failed` → Past due

### Subscription Tiers

```typescript
FREE:
  - Price: €0/month
  - Features:
    - Desktop DAW (all 80+ effects)
    - 5 cloud projects
    - 30-day trial
    - Community support

PRO:
  - Price: €29/month
  - Features:
    - Everything in Free
    - Unlimited cloud projects
    - iOS app access
    - Cloud sync
    - Priority support

STUDIO:
  - Price: €99/month
  - Features:
    - Everything in Pro
    - Team collaboration (coming soon)
    - API access
    - Custom integrations
    - Dedicated support
```

---

## ☁️ Cloud Storage Architecture

### File Upload Flow

1. **User uploads project from Desktop DAW**
2. **API receives multipart/form-data**
   - XML project file
   - Multiple audio files (WAV, FLAC, etc.)

3. **Backend processes upload**
   - Validates user has storage quota
   - Uploads files to S3/R2
   - Creates database records
   - Returns upload confirmation

4. **File structure in S3:**
   ```
   echoelmusic-projects/
   └── users/
       └── {userId}/
           ├── 1699999999-project.xml
           ├── 1699999999-kick.wav
           ├── 1699999999-bass.wav
           └── ...
   ```

### File Download Flow

1. **User requests project from Dashboard or DAW**
2. **API generates signed URLs** (1-hour expiration)
3. **User downloads directly from S3/R2**
4. **No files pass through backend** (efficient!)

---

## 🚀 Deployment Architecture

### Production Stack

```
┌─────────────────────────────────────────┐
│  Users (Desktop DAW + Web Dashboard)    │
└────────────┬────────────────────────────┘
             │
        HTTPS (SSL/TLS)
             │
┌────────────▼────────────────────────────┐
│         Cloudflare CDN                   │  ← DNS + DDoS protection
└────────────┬────────────────────────────┘
             │
    ┌────────┴────────┐
    │                 │
┌───▼──────────┐  ┌──▼──────────────┐
│   Vercel     │  │   Railway       │
│  (Frontend)  │  │  (Backend API)  │
│  - Next.js   │  │  - Express.js   │
│  - Static    │  │  - PostgreSQL   │
└──────────────┘  └──┬──────────────┘
                     │
        ┌────────────┼────────────┐
        │            │            │
   ┌────▼────┐  ┌───▼───┐  ┌────▼─────┐
   │ Stripe  │  │  AWS  │  │ Sendgrid │
   │Payments │  │  S3   │  │  Email   │
   └─────────┘  └───────┘  └──────────┘
```

### Deployment Steps

1. **Backend → Railway**
   - Auto-deploy from Git
   - PostgreSQL provisioned
   - Environment variables set
   - `npm run build` → Production build

2. **Frontend → Vercel**
   - Auto-deploy from Git
   - Next.js optimized build
   - CDN distribution
   - SSL certificate auto-provisioned

3. **Stripe Webhooks**
   - Point to Railway backend URL
   - Configure webhook secret

---

## 📊 Scalability Considerations

### Current MVP Limits

- **Users:** ~1,000 concurrent users
- **Projects:** ~10,000 total projects
- **Storage:** Up to 100GB (S3 Standard)
- **API Requests:** ~100,000/day

### Scaling Path (when needed)

**Phase 1:** Optimize Database
- Add database indexes
- Enable connection pooling
- Read replicas for analytics

**Phase 2:** Add Caching
- Redis for session management
- CloudFront CDN for S3 downloads
- API response caching

**Phase 3:** Horizontal Scaling
- Multiple backend instances (Railway auto-scaling)
- Load balancer (Railway provides)
- Database sharding (for >100k users)

---

## 🧪 Testing Strategy

### Backend Testing

```bash
# Unit tests (Jest)
npm test

# API integration tests
npm run test:integration

# Load testing (Artillery)
npm run test:load
```

### Frontend Testing

```bash
# Component tests
npm run test

# E2E tests (Playwright)
npm run test:e2e
```

---

## 📈 Monitoring & Analytics

### Production Monitoring

- **Railway:** Built-in metrics (CPU, Memory, Requests)
- **Vercel:** Analytics (page views, performance)
- **Stripe:** Payment analytics (MRR, churn)
- **Sentry:** Error tracking (optional)
- **Mixpanel:** User analytics (optional)

### Key Metrics to Track

- **Business:**
  - MRR (Monthly Recurring Revenue)
  - Churn rate
  - Trial → Paid conversion rate

- **Technical:**
  - API response time (< 200ms target)
  - Error rate (< 1% target)
  - Uptime (99.9% target)

---

## 🔄 CI/CD Pipeline

### Automated Deployment

```yaml
# GitHub Actions (example)
name: Deploy

on:
  push:
    branches: [main]

jobs:
  backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Deploy to Railway
        run: railway up

  frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Deploy to Vercel
        run: vercel --prod
```

---

## 🎯 Future Enhancements

### Phase 2 Features

- **Team Collaboration** (Studio tier)
- **Real-time sync** (WebSockets)
- **Mobile app** (React Native)
- **Plugin marketplace**
- **Social features** (share projects)

### Phase 3 Features

- **AI mastering**
- **Stem separation**
- **Music distribution** (Spotify, Apple Music)
- **NFT minting** (blockchain integration)

---

**Architecture designed for:**
- ✅ Rapid MVP development
- ✅ Easy maintenance
- ✅ Cost-effective scaling
- ✅ Future extensibility

**Built with modern best practices and production-ready from day 1!** 🚀
