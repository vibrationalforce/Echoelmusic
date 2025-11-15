# 🌐 Browser-Only Deployment Guide

**Deploy Echoelmusic Backend in ONE DAY - NO Computer/Terminal Needed!**

Perfect for: iPad, Chromebook, Library Computer, or any device with a browser

**Total Cost: €5/month** | **Time: 4-6 hours** | **Difficulty: Easy**

---

## ✅ WHAT YOU'LL NEED

```
✅ Any device with a browser (iPad, Phone, Chromebook, etc.)
✅ Credit/Debit card (for domain + server)
✅ Email: michaelterbuyken@gmail.com
✅ 4-6 hours of focused time
✅ €17 budget (€12 domain + €5 first month)
```

**NO NEED FOR:**
- ❌ Mac or PC
- ❌ Terminal/Command Line
- ❌ Coding knowledge
- ❌ Xcode or development tools

---

## 📅 4-HOUR DEPLOYMENT TIMELINE

```
Hour 1: Domain + Email (IONOS web dashboard)
Hour 2: GitHub Pages for Legal Docs (GitHub web interface)
Hour 3: Database + Payments (Supabase + Stripe dashboards)
Hour 4: Server Setup (Hetzner web console)

RESULT: Full backend running on api.echoelmusic.com! 🎉
```

---

## 🚀 STEP-BY-STEP (PURE BROWSER)

### ⏰ HOUR 1: Domain & Email Setup

#### Step 1.1: Buy Domain (15 min)

**Go to:** https://www.ionos.de

1. Click "Domains" in top menu
2. Search box: Type `echoelmusic.com`
3. Click "In den Warenkorb" (Add to cart)
4. Click "Zur Kasse" (Checkout)
5. Create account:
   - Email: `michaelterbuyken@gmail.com`
   - Password: (choose strong password)
   - Name: Michael Terbuyken
   - Address: Bahrenfelder Chaussee 35, 22761 Hamburg
6. Payment method: Credit card
7. Complete purchase

**Cost: €12/year** ✅

**Wait 5-10 minutes for domain activation email**

---

#### Step 1.2: Email Forwarding (20 min)

**In IONOS Dashboard:**

1. Click "Domains & SSL" in left menu
2. Click on `echoelmusic.com`
3. Click "Email" tab
4. Click "Email-Weiterleitung einrichten" (Setup email forwarding)
5. Add these forwarding rules:
   ```
   hello@echoelmusic.com → michaelterbuyken@gmail.com
   support@echoelmusic.com → michaelterbuyken@gmail.com
   press@echoelmusic.com → michaelterbuyken@gmail.com
   ```
6. Click "Speichern" (Save)

**Test:** Send email to hello@echoelmusic.com, check Gmail ✅

---

#### Step 1.3: Gmail "Send As" Setup (15 min)

**In Gmail:**

1. Click ⚙️ (Settings) → "See all settings"
2. Click "Accounts and Import" tab
3. Under "Send mail as", click "Add another email address"
4. Name: `Echoel`
5. Email: `hello@echoelmusic.com`
6. Uncheck "Treat as an alias"
7. Click "Next Step"

**SMTP Settings:**
```
SMTP Server: smtp.ionos.de
Port: 587
Username: hello@echoelmusic.com
Password: (create in IONOS → Email → Mailbox erstellen)
```

8. Back to IONOS:
   - Domains & SSL → echoelmusic.com
   - Email → "Postfach erstellen" (Create mailbox)
   - Email: hello@echoelmusic.com
   - Password: (choose strong password - save it!)
   - Speicherplatz: 2GB (smallest)
   - Speichern

9. Back to Gmail, enter password
10. Click "Add Account"
11. Check email for verification link
12. Click verification link

**Test:** Compose email in Gmail, change "From" to hello@echoelmusic.com ✅

---

### ⏰ HOUR 2: GitHub Pages (Legal Docs)

#### Step 2.1: Create Repository (10 min)

**Go to:** https://github.com/vibrationalforce/Echoelmusic

1. Click green "Code" button
2. Click "Download ZIP"
3. Extract ZIP on your device
4. Go to: https://github.com/new
5. Repository name: `echoelmusic-legal`
6. Description: `Legal documents for Echoelmusic (DSGVO, AGB, Impressum)`
7. Public ✅
8. Click "Create repository"

---

#### Step 2.2: Upload Legal Pages (20 min)

**In your new repository:**

1. Click "uploading an existing file"
2. Drag & drop ALL files from `legal-pages/` folder:
   - index.html
   - datenschutz.html
   - agb.html
   - impressum.html
   - styles.css
   - README.md
3. Commit message: `Add legal pages (DSGVO, AGB, Impressum)`
4. Click "Commit changes"

---

#### Step 2.3: Activate GitHub Pages (5 min)

**In repository:**

1. Click "Settings" (top right)
2. Scroll down left menu → Click "Pages"
3. Under "Source":
   - Branch: `main`
   - Folder: `/ (root)`
4. Click "Save"
5. Wait 2-3 minutes

**Your legal pages are now live at:**
```
https://vibrationalforce.github.io/echoelmusic-legal/
```

**Test:** Click the URL, verify all pages work ✅

---

#### Step 2.4: Update Domain DNS (15 min)

**Back to IONOS Dashboard:**

1. Domains & SSL → echoelmusic.com
2. Click "DNS" tab
3. Click "Add Record"
4. Type: `CNAME`
5. Host: `legal`
6. Points to: `vibrationalforce.github.io`
7. TTL: 3600
8. Save

**Wait 10-30 minutes for DNS propagation**

**Your legal pages will be at:**
```
https://legal.echoelmusic.com (custom domain)
OR
https://vibrationalforce.github.io/echoelmusic-legal/ (GitHub)
```

---

### ⏰ HOUR 3: Database & Payments

#### Step 3.1: Supabase Database (20 min)

**Go to:** https://supabase.com

1. Click "Start your project"
2. Sign up with GitHub (easier) or email
3. Click "New project"
4. Settings:
   - Name: `echoelmusic-production`
   - Database Password: (generate strong password - SAVE IT!)
   - Region: `Europe (Frankfurt)`
   - Pricing Plan: `Free`
5. Click "Create new project"

**Wait 2-3 minutes for database creation**

---

#### Step 3.2: Create Database Schema (15 min)

**In Supabase Dashboard:**

1. Click "SQL Editor" in left menu
2. Click "+ New query"
3. Copy-paste this entire schema:

```sql
-- Users table
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  username TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  tier TEXT DEFAULT 'Free',
  created_at TIMESTAMPTZ DEFAULT NOW(),
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

4. Click "Run" (▶️ button)
5. Should see "Success. No rows returned"

---

#### Step 3.3: Get API Credentials (5 min)

**In Supabase Dashboard:**

1. Click "Settings" (gear icon bottom left)
2. Click "API" in left submenu
3. **Copy these values to Notes app:**
   ```
   Project URL: https://xxxxx.supabase.co
   anon/public key: eyJhbGc...
   service_role key: eyJhbGc... (keep secret!)
   ```

**SAVE THESE! You'll need them later.**

---

#### Step 3.4: Stripe Payment Setup (20 min)

**Go to:** https://stripe.com

1. Click "Start now" → "Sign up"
2. Business information:
   - Business type: `Individual`
   - Country: `Germany`
   - Business name: `Echoel` (or `Michael Terbuyken`)
   - Email: `hello@echoelmusic.com`
3. Verify email (click link in email)
4. Complete profile:
   - Full name: Michael Terbuyken
   - Date of birth: (your DOB)
   - Address: Bahrenfelder Chaussee 35, 22761 Hamburg
   - Phone: (your phone)
5. Bank account:
   - IBAN: `DE66 3701 0050 0705 7105 00`
   - Bank: Postbank
6. Identity verification:
   - Upload Personalausweis (front + back)
   - Take selfie (if required)

**Wait 1-2 business days for verification** ⏳

---

#### Step 3.5: Create Products in Stripe (10 min)

**In Stripe Dashboard:**

1. Click "Products" in left menu
2. Click "+ Add product"

**Product 1: Echoelmusic Pro**
```
Name: Echoelmusic Pro
Description: Cloud sync, advanced effects, AI features
Pricing model: Recurring
Price: €9.99
Billing period: Monthly
Currency: EUR
```
Click "Add product"

**Product 2: Echoelmusic Studio**
```
Name: Echoelmusic Studio
Description: Everything in Pro + video export, priority support
Pricing model: Recurring
Price: €19.99
Billing period: Monthly
Currency: EUR
```
Click "Add product"

---

#### Step 3.6: Get Stripe API Keys (5 min)

**In Stripe Dashboard:**

1. Click "Developers" in left menu
2. Click "API keys"
3. **Copy to Notes app:**
   ```
   Publishable key: pk_live_...
   Secret key: sk_live_... (click "Reveal")
   ```

**SAVE THESE!**

---

### ⏰ HOUR 4: Server Setup

#### Step 4.1: Create Hetzner Server (15 min)

**Go to:** https://www.hetzner.com/cloud

1. Click "Sign Up"
2. Email: michaelterbuyken@gmail.com
3. Verify email
4. Add payment method (credit card)
5. Click "New Project"
   - Name: `Echoelmusic Production`
6. Click "Add Server"
7. Location: `Falkenstein, Germany` (closest to Hamburg)
8. Image: `Ubuntu 22.04`
9. Type: `CX11` (€4.15/month)
   - 1 vCPU, 2 GB RAM, 20 GB SSD
10. Networking: Default (IPv4 + IPv6)
11. SSH Keys: Click "Add SSH key"
    - **Problem:** Need to generate SSH key...

---

#### Step 4.2: SSH Key Generation (Browser Method)

**Option A: Use Hetzner Console (NO SSH key needed!)**

Skip SSH key for now, we'll use Hetzner's web console!

1. Don't add SSH key, continue
2. Server name: `echoelmusic-api`
3. Click "Create & Buy now"

**Server is created in ~30 seconds!**

Note the server IP address: `116.203.XXX.XXX`

---

#### Step 4.3: Access Server via Web Console (5 min)

**In Hetzner Cloud Console:**

1. Click on your server name
2. Click "Console" button (top right, looks like >_)
3. Web-based terminal opens!
4. Login as `root` (password was emailed to you)

**You're now in the server terminal - in your browser!** 🎉

---

#### Step 4.4: Install Docker (10 min)

**In web console, paste these commands ONE BY ONE:**

```bash
# Update system
apt-get update && apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Install Docker Compose
apt-get install docker-compose -y

# Verify
docker --version
docker-compose --version
```

Each command will output some text. Wait for each to finish before next one.

---

#### Step 4.5: Install Nginx & Certbot (5 min)

```bash
# Install Nginx
apt-get install nginx -y

# Install Certbot for SSL
apt-get install certbot python3-certbot-nginx -y

# Verify
nginx -v
certbot --version
```

---

#### Step 4.6: Configure DNS (10 min)

**Back to IONOS Dashboard (new browser tab):**

1. Domains & SSL → echoelmusic.com
2. DNS Settings
3. Add A Record:
   - Type: `A`
   - Host: `api`
   - Points to: `116.203.XXX.XXX` (your Hetzner server IP)
   - TTL: 3600
4. Save

**Wait 5-10 minutes for DNS propagation**

**Test:**
```
Open new tab: http://116.203.XXX.XXX
Should see "Welcome to nginx!"
```

---

#### Step 4.7: Clone Repository (Browser Method)

**In Hetzner web console:**

```bash
# Install git
apt-get install git -y

# Create deploy directory
mkdir -p /opt/echoelmusic
cd /opt/echoelmusic

# Clone repo (public, no auth needed)
git clone https://github.com/vibrationalforce/Echoelmusic.git .

# Verify
ls
# Should see: backend/ automation/ legal-pages/ etc.
```

---

#### Step 4.8: Configure Environment (15 min)

```bash
cd backend

# Create .env file from template
cp .env.minimal .env

# Edit .env file (nano is text editor in browser!)
nano .env
```

**In nano editor, fill in your values:**

Press arrow keys to navigate, type to edit:

```bash
# Change these lines to your actual values:

SUPABASE_URL=https://xxxxx.supabase.co  # From Step 3.3
SUPABASE_ANON_KEY=eyJhbGc...  # From Step 3.3
SUPABASE_SERVICE_KEY=eyJhbGc...  # From Step 3.3

STRIPE_SECRET_KEY=sk_live_...  # From Step 3.6
STRIPE_PUBLISHABLE_KEY=pk_live_...  # From Step 3.6

# Generate JWT secret (random 64 characters):
JWT_SECRET=your_super_long_random_string_here_min_64_chars_use_password_generator
```

**Save & Exit:**
- Press `Ctrl + X`
- Press `Y` (yes, save)
- Press `Enter` (confirm filename)

---

#### Step 4.9: Start Backend (10 min)

```bash
# Build and start
docker-compose -f docker-compose.minimal.yml up -d

# Wait ~2 minutes for build

# Check if running
docker-compose -f docker-compose.minimal.yml ps

# Should see:
# echoelmusic-api    running
# echoelmusic-nginx  running
```

**Test backend:**
```bash
curl http://localhost:3000/health
```

Should return: `{"status":"healthy"}` ✅

---

#### Step 4.10: SSL Certificate (10 min)

```bash
# Get Let's Encrypt certificate
certbot --nginx -d api.echoelmusic.com

# Answer prompts:
# Email: hello@echoelmusic.com
# Agree to terms: Y
# Share email: N (optional)
# Redirect HTTP to HTTPS: 2 (yes)
```

**Wait 1-2 minutes for certificate**

**Test SSL:**

Open browser tab: `https://api.echoelmusic.com/health`

Should see: `{"status":"healthy"}` ✅

**Check SSL rating:** https://www.ssllabs.com/ssltest/
Enter: `api.echoelmusic.com`
Should get: **A or A+** rating! 🎉

---

### ⏰ FINAL HOUR: Testing & Monitoring

#### Step 5.1: Test All Endpoints (10 min)

**Open browser, test these URLs:**

1. **Health check:**
   ```
   https://api.echoelmusic.com/health
   ```
   Should return: `{"status":"healthy"}`

2. **Legal pages:**
   ```
   https://vibrationalforce.github.io/echoelmusic-legal/
   ```
   Should show: Legal homepage with navigation

3. **Email forwarding:**
   - Send test email to: hello@echoelmusic.com
   - Check Gmail inbox
   - Reply from Gmail using hello@echoelmusic.com

All working? ✅ **BACKEND IS LIVE!**

---

#### Step 5.2: Setup Monitoring (15 min)

**Go to:** https://uptimerobot.com

1. Sign up (free account)
2. Click "Add New Monitor"
3. Settings:
   - Monitor Type: `HTTPS`
   - Friendly Name: `Echoelmusic API`
   - URL: `https://api.echoelmusic.com/health`
   - Monitoring Interval: `5 minutes`
4. Alert Contacts:
   - Email: michaelterbuyken@gmail.com
5. Create Monitor

**Now you'll get email alerts if API goes down!**

---

#### Step 5.3: Setup Error Tracking (10 min)

**Go to:** https://sentry.io

1. Sign up (free account)
2. "Create Project"
3. Platform: `Node.js`
4. Project name: `echoelmusic-api`
5. Create Project
6. Copy DSN: `https://xxxxx@sentry.io/xxxxx`

**Add to server:**

```bash
# SSH back into server (Hetzner console)
cd /opt/echoelmusic/backend
nano .env

# Add line:
SENTRY_DSN=https://xxxxx@sentry.io/xxxxx

# Save (Ctrl+X, Y, Enter)

# Restart backend
docker-compose -f docker-compose.minimal.yml restart
```

**Now errors are tracked automatically!**

---

## 🎉 DEPLOYMENT COMPLETE!

### What You Built (Browser Only!):

✅ **Domain:** echoelmusic.com with professional email
✅ **Legal Pages:** DSGVO-compliant docs (GitHub Pages, FREE)
✅ **Database:** Supabase PostgreSQL (FREE tier)
✅ **Payments:** Stripe ready (FREE + 2.9% per transaction)
✅ **Backend API:** Running on Hetzner (€4/month)
✅ **SSL:** A+ rating with Let's Encrypt (FREE)
✅ **Monitoring:** UptimeRobot + Sentry (FREE)

### Monthly Cost Breakdown:

```
Domain: €1/month (€12/year)
Server: €4.15/month (Hetzner CX11)
Everything else: €0 (free tiers)

TOTAL: €5.15/month 🎉
```

### What's Live:

- ✅ API: https://api.echoelmusic.com
- ✅ Legal: https://vibrationalforce.github.io/echoelmusic-legal/
- ✅ Email: hello@echoelmusic.com
- ✅ Monitoring: Active (UptimeRobot + Sentry)

---

## 📱 Next Steps: iOS Apps

Your backend is ready! Apps can connect to it.

For building iOS apps, you have 3 options:

**Option 1: MacinCloud** (€30/month for 1 month)
- https://www.macincloud.com
- Rent Mac in cloud
- Access via browser
- Build apps, setup certificates
- Cancel after setup (GitHub Actions auto-builds afterwards)

**Option 2: Borrow/Rent Mac**
- Apple Store, Friend, Coworking Space
- 1 day to setup certificates & GitHub Actions
- Then deploy via Git tags (automatic)

**Option 3: Freelancer** (€200-500 one-time)
- Hire on Upwork/Fiverr
- They setup certificates & CI/CD
- You just push code afterwards

---

## 🆘 Troubleshooting (Browser Only)

### Backend not responding?

**Check logs (Hetzner console):**
```bash
cd /opt/echoelmusic/backend
docker-compose -f docker-compose.minimal.yml logs -f api
```

Press `Ctrl+C` to exit logs.

### Need to restart backend?

```bash
docker-compose -f docker-compose.minimal.yml restart
```

### DNS not working?

Wait 30 minutes (propagation takes time).

Test with: https://dnschecker.org
Enter: api.echoelmusic.com

### Forgot credentials?

**Supabase:** Dashboard → Settings → API
**Stripe:** Dashboard → Developers → API keys
**Server IP:** Hetzner Cloud Console → Servers

---

## ✅ Final Checklist

Before going live, verify:

```
Backend:
☐ API health check: https://api.echoelmusic.com/health returns OK
☐ SSL certificate valid (A+ on SSL Labs)
☐ Monitoring active (UptimeRobot)
☐ Error tracking active (Sentry)

Legal:
☐ Legal pages live and accessible
☐ All links work (Datenschutz, AGB, Impressum)

Email:
☐ Can receive at hello@echoelmusic.com
☐ Can send from hello@echoelmusic.com (Gmail)
☐ Forwarding works for support@ and press@

Services:
☐ Supabase database created and tables exist
☐ Stripe account verified (may take 1-2 days)
☐ Products created (Pro €9.99, Studio €19.99)

Domain & DNS:
☐ echoelmusic.com resolves
☐ api.echoelmusic.com points to server
☐ legal.echoelmusic.com points to GitHub Pages (optional)
```

---

## 🎉 YOU DID IT!

**Congratulations! You deployed a production backend WITHOUT any terminal or computer!**

**Total time:** 4-6 hours
**Total cost:** €5/month
**All done in browser:** iPad, Chromebook, Phone, Library computer ✅

**Your backend is ready for:**
- User registration & authentication
- Cloud sync
- Payment processing
- Legal compliance (DSGVO)
- Professional monitoring

**Next:** Build & deploy apps (needs Mac/MacinCloud or freelancer)

---

**Questions?** Check main guides:
- [DEPLOY_NOW_GUIDE.md](DEPLOY_NOW_GUIDE.md) - Terminal version
- [MINIMAL_COST_SETUP.md](MINIMAL_COST_SETUP.md) - Cost details
- [AUTOMATION_GUIDE.md](AUTOMATION_GUIDE.md) - Full automation

---

**Created with ❤️ for solo artists deploying on a budget**

Michael, you can literally do this from an iPad in a café! 🎨☕

No Mac needed until you want to build the apps! 🚀
