# 🚀 Echoelmusic - Deploy NOW Guide

**From Zero to Production in One Day**
**Total Cost: €129 first month, €13/month ongoing**

Perfect for: Solo artist launching an affordable, sustainable music production app

---

## ✅ PREREQUISITES CHECKLIST

Before you start, prepare these:

```
Personal Information:
☐ Full name: Michael Terbuyken (Echoel)
☐ Address: Bahrenfelder Chaussee 35, 22761 Hamburg, Germany
☐ Email: michaelterbuyken@gmail.com
☐ Phone number (for account verification)

Payment Method:
☐ Credit/Debit card for service signups
☐ Bank account: Postbank (IBAN: DE66 3701 0050 0705 7105 00)

Development Environment:
☐ Mac with Xcode installed (for iOS/macOS)
☐ GitHub account: vibrationalforce
☐ Basic command line knowledge
```

---

## 🎯 DEPLOYMENT PATH

You have 3 options. I recommend **Option 2** (Minimal Cost):**

### Option 1: Absolute Minimum (€1/month + €124 one-time)
- ✅ Just domain + email forwarding
- ✅ Host legal docs on GitHub Pages (free)
- ✅ No backend yet (local-only app)
- ✅ Deploy to App Stores
- **Best for:** Testing the market with MVP

### Option 2: Minimal Backend (€13/month + €124 one-time) ⭐ RECOMMENDED
- ✅ Everything from Option 1
- ✅ Backend API on Hetzner (€4/month)
- ✅ Supabase database (free tier)
- ✅ Cloud sync + user accounts
- ✅ Payment processing (Stripe)
- **Best for:** Full-featured launch on a budget

### Option 3: Full Automation (€150/month + €124 one-time)
- ✅ Everything from Option 2
- ✅ AI chatbot support (Intercom €50/mo)
- ✅ Advanced analytics (Mixpanel Pro €20/mo)
- ✅ Marketing automation (Buffer €15/mo, Mailchimp €13/mo)
- ✅ All premium tiers
- **Best for:** When you have 500+ paying customers

**This guide covers Option 2 (Minimal Backend) ⭐**

---

## 📅 ONE-DAY DEPLOYMENT TIMELINE

### Morning (4 hours)
- ☐ 09:00 - 09:30: Buy domain & setup email
- ☐ 09:30 - 10:00: Deploy GitHub Pages (legal docs)
- ☐ 10:00 - 10:30: Create Supabase account & database
- ☐ 10:30 - 11:00: Create Stripe account
- ☐ 11:00 - 12:00: Setup Hetzner server
- ☐ 12:00 - 13:00: Lunch break 🍕

### Afternoon (4 hours)
- ☐ 13:00 - 14:00: Deploy backend to server
- ☐ 14:00 - 14:30: Configure SSL certificate
- ☐ 14:30 - 15:00: Test API endpoints
- ☐ 15:00 - 16:00: Setup monitoring & backups
- ☐ 16:00 - 17:00: Final testing

### Evening (2 hours) - Optional
- ☐ 17:00 - 18:00: Create Apple Developer account
- ☐ 18:00 - 19:00: Create Google Play account

**Total: 8-10 hours to production-ready backend! 🎉**

---

## 🔧 STEP-BY-STEP DEPLOYMENT

### STEP 1: Domain & Email (30 min) - €12/year

#### 1.1 Buy Domain

```bash
# Go to IONOS.de or Namecheap.com
https://www.ionos.de

# Search for: echoelmusic.com
# Price: ~€12/year (€1/month)
# Add to cart → Checkout

# DNS Settings will be available in ~10 minutes
```

#### 1.2 Setup Email Forwarding

```bash
# In IONOS Dashboard:
# 1. Go to "Domains & SSL"
# 2. Click on echoelmusic.com
# 3. Go to "Email" → "Email Forwarding"
# 4. Add forwarding rules:

hello@echoelmusic.com → michaelterbuyken@gmail.com
support@echoelmusic.com → michaelterbuyken@gmail.com
press@echoelmusic.com → michaelterbuyken@gmail.com

# Save changes
```

#### 1.3 Configure Gmail "Send As"

```bash
# In Gmail:
# 1. Click Settings (gear icon) → "See all settings"
# 2. Go to "Accounts and Import" tab
# 3. Click "Add another email address"
# 4. Name: Echoel
#    Email: hello@echoelmusic.com
# 5. SMTP Server: smtp.ionos.de
#    Port: 587
#    Username: hello@echoelmusic.com
#    Password: (create in IONOS dashboard)
# 6. Verify email (click link in confirmation email)

# Now you can send from hello@echoelmusic.com via Gmail!
```

**Cost: €12/year = €1/month ✅**

---

### STEP 2: GitHub Pages for Legal Docs (30 min) - FREE

```bash
# From your local machine:
cd ~/Projects/Echoelmusic

# Create new repo for legal pages
gh repo create echoelmusic-legal --public --confirm

# Push legal pages
cd legal-pages
git init
git add .
git commit -m "Initial legal pages: DSGVO, AGB, Impressum"
git branch -M main
git remote add origin https://github.com/vibrationalforce/echoelmusic-legal.git
git push -u origin main

# Enable GitHub Pages:
# 1. Go to https://github.com/vibrationalforce/echoelmusic-legal
# 2. Click "Settings" → "Pages"
# 3. Source: "main" branch, "/ (root)" folder
# 4. Click "Save"

# Wait 2-3 minutes, then visit:
# https://vibrationalforce.github.io/echoelmusic-legal/

# Your legal pages are live! ✅
```

**Cost: FREE ✅**

---

### STEP 3: Supabase Database (30 min) - FREE

```bash
# 1. Create account at https://supabase.com
# Use: michaelterbuyken@gmail.com

# 2. Create new project
Name: echoelmusic-production
Database Password: (generate strong password - save it!)
Region: Europe (Frankfurt)
Plan: Free tier

# 3. Wait for database to provision (~2 min)

# 4. Create database schema
# Go to SQL Editor → New query

# Copy-paste this schema:
```

```sql
-- Users table
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  username TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  tier TEXT DEFAULT 'Free',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  first_project_at TIMESTAMPTZ,
  first_export_at TIMESTAMPTZ,
  trial_started_at TIMESTAMPTZ,
  projects_count INTEGER DEFAULT 0,
  exports_count INTEGER DEFAULT 0
);

-- Projects table
CREATE TABLE projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  type TEXT DEFAULT 'Audio',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  data JSONB
);

-- Subscriptions table
CREATE TABLE subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  tier TEXT NOT NULL,
  status TEXT DEFAULT 'active',
  amount DECIMAL(10,2) NOT NULL,
  billing_cycle TEXT DEFAULT 'monthly',
  stripe_subscription_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  cancelled_at TIMESTAMPTZ
);

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own data" ON users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can view own projects" ON projects
  FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can view own subscriptions" ON subscriptions
  FOR SELECT USING (auth.uid() = user_id);
```

```bash
# 5. Get API credentials
# Go to Settings → API
# Copy these values:

SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGc...
SUPABASE_SERVICE_KEY=eyJhbGc...  (keep secret!)

# Save these - you'll need them later!
```

**Cost: FREE (up to 500MB DB, 1GB storage, 50k MAU) ✅**

---

### STEP 4: Stripe Payment Processing (30 min) - FREE

```bash
# 1. Create account at https://stripe.com
# Business type: Individual
# Business name: Echoel (Michael Terbuyken)
# Address: Bahrenfelder Chaussee 35, 22761 Hamburg, Germany
# Email: hello@echoelmusic.com
# Bank: Postbank (IBAN: DE66 3701 0050 0705 7105 00)

# 2. Complete identity verification
# Upload ID (Personalausweis)
# Wait for approval (~1-2 business days)

# 3. Create products
# Go to Products → Add Product

Product 1:
  Name: Echoelmusic Pro
  Price: €9.99/month
  Recurring: Monthly

Product 2:
  Name: Echoelmusic Studio
  Price: €19.99/month
  Recurring: Monthly

# 4. Setup webhook
# Go to Developers → Webhooks → Add endpoint
# Endpoint URL: https://api.echoelmusic.com/webhooks/stripe
# Events to listen:
#   - customer.subscription.created
#   - customer.subscription.updated
#   - customer.subscription.deleted
#   - invoice.payment_succeeded
#   - invoice.payment_failed

# 5. Get API keys
# Go to Developers → API keys
# Copy:

STRIPE_SECRET_KEY=sk_live_...
STRIPE_PUBLISHABLE_KEY=pk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...  (from webhook settings)

# Save these!
```

**Cost: FREE + 2.9% + €0.30 per transaction ✅**

---

### STEP 5: Hetzner Server (1 hour) - €4.15/month

```bash
# 1. Create account at https://www.hetzner.com/cloud
# Email: michaelterbuyken@gmail.com

# 2. Add payment method (credit card)

# 3. Create new project
# Name: Echoelmusic Production

# 4. Create server
# Location: Falkenstein, Germany (closest to Hamburg)
# Image: Ubuntu 22.04
# Type: CX11 (1 vCPU, 2GB RAM, 20GB SSD)
# SSH key: (create if you don't have one)
#   ssh-keygen -t ed25519 -C "michaelterbuyken@gmail.com"
#   cat ~/.ssh/id_ed25519.pub  # Copy this
# Network: Default
# Backups: No (we do manual backups to S3)

# Cost: €4.15/month

# 5. Wait for server to be created (~30 seconds)
# Note the IP address: e.g., 116.203.XXX.XXX

# 6. Configure DNS
# Back to IONOS → Domains → echoelmusic.com → DNS Settings
# Add A record:
#   api.echoelmusic.com → 116.203.XXX.XXX (your server IP)
# Wait 5-10 minutes for DNS propagation

# 7. SSH into server
ssh root@116.203.XXX.XXX

# 8. Update system
apt-get update && apt-get upgrade -y

# 9. Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# 10. Install Docker Compose
apt-get install docker-compose -y

# 11. Install Nginx
apt-get install nginx -y

# 12. Install Certbot (for SSL)
apt-get install certbot python3-certbot-nginx -y

# 13. Create deploy user
adduser deploy
# Password: (choose strong password)
usermod -aG docker deploy
usermod -aG sudo deploy

# 14. Setup SSH for deploy user
mkdir /home/deploy/.ssh
cp ~/.ssh/authorized_keys /home/deploy/.ssh/
chown -R deploy:deploy /home/deploy/.ssh
chmod 700 /home/deploy/.ssh
chmod 600 /home/deploy/.ssh/authorized_keys

# 15. Test deploy user login
# From your local machine:
ssh deploy@116.203.XXX.XXX
# Should work without password ✅

# Server setup complete!
```

**Cost: €4.15/month ✅**

---

### STEP 6: Deploy Backend (1 hour) - FREE

```bash
# On your local machine:

# 1. Clone repo to server
ssh deploy@api.echoelmusic.com
git clone https://github.com/vibrationalforce/Echoelmusic.git /opt/echoelmusic
cd /opt/echoelmusic/backend

# 2. Create production .env file
cp .env.minimal .env
nano .env

# Fill in all the credentials you collected:
# - Supabase (from Step 3)
# - Stripe (from Step 4)
# - JWT secret (generate: openssl rand -hex 32)
# - AWS credentials (if using S3)

# 3. Build and start services
docker-compose -f docker-compose.minimal.yml up -d

# 4. Check if services are running
docker-compose -f docker-compose.minimal.yml ps

# Should see:
# echoelmusic-api    running
# echoelmusic-nginx  running

# 5. Test API
curl http://localhost:3000/health
# Should return: {"status":"healthy"}

# Backend is running! ✅
```

---

### STEP 7: SSL Certificate (30 min) - FREE

```bash
# Still on server:

# 1. Get Let's Encrypt certificate
certbot --nginx -d api.echoelmusic.com --email hello@echoelmusic.com --agree-tos

# Answer prompts:
# - Agree to terms: Yes
# - Share email: No (optional)
# - Redirect HTTP to HTTPS: Yes (2)

# 2. Test certificate
curl https://api.echoelmusic.com/health
# Should return: {"status":"healthy"}

# 3. Test SSL rating
# Visit: https://www.ssllabs.com/ssltest/
# Enter: api.echoelmusic.com
# Should get: A or A+ rating

# 4. Setup auto-renewal
crontab -e
# Add this line:
0 5 1 * * certbot renew --nginx

# SSL configured! ✅
```

**Cost: FREE (Let's Encrypt) ✅**

---

### STEP 8: Monitoring & Backups (30 min) - FREE

```bash
# 1. Setup monitoring (UptimeRobot)
# Visit: https://uptimerobot.com
# Create account (free)
# Add monitor:
#   - Type: HTTPS
#   - URL: https://api.echoelmusic.com/health
#   - Name: Echoelmusic API
#   - Monitoring Interval: 5 minutes
#   - Alert contacts: michaelterbuyken@gmail.com

# 2. Setup error tracking (Sentry)
# Visit: https://sentry.io
# Create account (free tier)
# Create project: Echoelmusic
# Copy DSN: https://xxxxx@sentry.io/xxxxx
# Add to .env:
SENTRY_DSN=https://xxxxx@sentry.io/xxxxx

# 3. Setup automated backups
cd /opt/echoelmusic/automation/scripts
chmod +x *.sh

# Test backup
./database-backup.sh production

# Should upload to S3 (if configured) or create local backup

# 4. Setup cron for automated backups
./crontab-setup.sh production
# Confirms cron jobs

# Monitoring complete! ✅
```

**Cost: FREE ✅**

---

### STEP 9: Final Testing (30 min)

```bash
# Test all endpoints:

# 1. Health check
curl https://api.echoelmusic.com/health
# Expected: {"status":"healthy"}

# 2. Database connection
curl https://api.echoelmusic.com/api/health/db
# Expected: {"status":"healthy", "database":"connected"}

# 3. Test user registration
curl -X POST https://api.echoelmusic.com/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","username":"testuser","password":"Test123!"}'
# Expected: {"user":{...},"token":"eyJhbGc..."}

# 4. Test login
curl -X POST https://api.echoelmusic.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test123!"}'
# Expected: {"user":{...},"token":"eyJhbGc..."}

# All tests pass? ✅ BACKEND IS LIVE!
```

---

## 🎉 DEPLOYMENT COMPLETE!

### What You've Built:

✅ **Domain & Email:** echoelmusic.com with professional email
✅ **Legal Pages:** DSGVO-compliant docs on GitHub Pages (free!)
✅ **Database:** Supabase with proper schema (free tier)
✅ **Payments:** Stripe integration ready
✅ **Backend API:** Running on Hetzner (€4/month)
✅ **SSL Certificate:** A+ rating with Let's Encrypt (free)
✅ **Monitoring:** UptimeRobot + Sentry (free)
✅ **Backups:** Automated daily backups

### Monthly Costs:

```
Domain: €1/month
Server: €4.15/month
Supabase: €0 (free tier)
Stripe: €0 + 2.9% per transaction
GitHub: €0 (Actions free tier)
UptimeRobot: €0 (free tier)
Sentry: €0 (free tier)

TOTAL: €5.15/month 🎉
```

### One-Time Costs:

```
Domain (first year): €12
Apple Developer: €99/year (when ready to submit to App Store)
Google Play: €25 (one-time, when ready to submit)

TOTAL FIRST MONTH: €5 + €99 + €25 = €129
```

---

## 📱 NEXT STEPS: App Store Deployment

Now that your backend is live, you can deploy to app stores:

### iOS/macOS (Apple App Store)

```bash
# See AUTOMATION_SETUP_GUIDE.md, Section 2
# Required:
# - Apple Developer account (€99/year)
# - Code signing certificates
# - Provisioning profiles
# - GitHub Secrets configured

# Quick summary:
1. Generate certificates in Xcode
2. Create App ID in Apple Developer
3. Setup GitHub Secrets
4. Push git tag: git tag v1.0.0 && git push origin v1.0.0
5. GitHub Actions builds and submits to TestFlight
6. Test on TestFlight
7. Submit for App Store review
```

### Android (Google Play)

```bash
# See AUTOMATION_SETUP_GUIDE.md, Section 2
# Required:
# - Google Play Console account (€25 one-time)
# - Android keystore
# - Service account JSON
# - GitHub Secrets configured

# Quick summary:
1. Create keystore: keytool -genkey ...
2. Create Google Play service account
3. Setup GitHub Secrets
4. Push git tag: git tag v1.0.0 && git push origin v1.0.0
5. GitHub Actions builds and uploads to Play Console
6. Test internal track
7. Submit for review
```

### Windows/Linux

```bash
# Direct downloads via CDN (already setup in GitHub Actions)
# Users download .exe (Windows) or .AppImage (Linux) from:
# https://echoelmusic.com/download

# Optional: Submit to Microsoft Store, Flathub, Snap Store
# (GitHub Actions already configured for this)
```

---

## 🆘 TROUBLESHOOTING

### Backend not starting?

```bash
# Check logs
docker-compose -f docker-compose.minimal.yml logs -f api

# Common issues:
# - Missing .env file → Copy from .env.minimal
# - Wrong database URL → Check Supabase dashboard
# - Port 3000 already in use → Change PORT in .env
```

### SSL certificate issues?

```bash
# Check Nginx config
nginx -t

# Renew certificate manually
certbot renew --nginx

# Check DNS propagation
dig api.echoelmusic.com

# Should show your server IP
```

### Database connection failing?

```bash
# Test Supabase connection
psql "postgresql://postgres:PASSWORD@db.xxx.supabase.co:5432/postgres"

# Check if firewall allows connections
# Supabase IPs should be whitelisted (default: all IPs allowed)
```

---

## 📚 DOCUMENTATION REFERENCE

- **Full Setup:** `AUTOMATION_SETUP_GUIDE.md`
- **Minimal Cost:** `MINIMAL_COST_SETUP.md`
- **Automation:** `AUTOMATION_GUIDE.md`
- **Artist Vision:** `ARTIST_VISION.md`
- **Legal Pages:** `legal-pages/README.md`

---

## ✅ FINAL CHECKLIST

Before going live, verify:

```
Backend:
☐ API health check passes
☐ Database connection works
☐ User registration/login works
☐ SSL certificate valid (A+ rating)
☐ Monitoring active (UptimeRobot)
☐ Backups configured (daily cron)

Legal:
☐ Datenschutz page live
☐ AGB page live
☐ Impressum page live
☐ All pages accessible from apps

Email:
☐ Can receive at hello@echoelmusic.com
☐ Can send from hello@echoelmusic.com via Gmail
☐ support@ and press@ forwarding works

Payment:
☐ Stripe account verified
☐ Products created (Pro €9.99, Studio €19.99)
☐ Webhook configured
☐ Bank account connected

Domain & DNS:
☐ echoelmusic.com resolves
☐ api.echoelmusic.com → Server IP
☐ Email forwarding works
☐ SSL certificate valid
```

---

## 🎉 YOU'RE READY TO LAUNCH!

**Backend is production-ready at €5/month.**

Now build your apps, submit to stores, and let's make some fucking great music together! 🚀🎵

**Questions?** → hello@echoelmusic.com

**Let's go, Michael! Your dream is live! 💙**

---

**Last updated:** November 15, 2024
**Maintained by:** Michael Terbuyken (Echoel)
**Total deployment time:** 8-10 hours
**Total cost:** €5/month + €124 one-time
