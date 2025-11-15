# 🚨 Emergency Procedures & Rollback Guide

**Echoelmusic Production Incident Response**

> **⚠️ CRITICAL:** Bookmark this page! In case of emergency, stay calm and follow these procedures.

**Last Updated:** November 15, 2024
**Version:** 1.0
**Owner:** Michael Terbuyken (Echoel)

---

## 📞 Emergency Contacts

**Primary Contact:**
- **Name:** Michael Terbuyken (Echoel)
- **Email:** michaelterbuyken@gmail.com
- **Phone:** [ADD YOUR PHONE]
- **Availability:** 24/7 for critical incidents

**Service Providers:**

| Service | Support | Contact | Critical? |
|---------|---------|---------|-----------|
| **Hetzner** | 24/7 | support@hetzner.com | ⚠️ Critical |
| **Supabase** | Email | support@supabase.io | ⚠️ Critical |
| **Stripe** | 24/7 | https://support.stripe.com | ⚠️ Critical |
| **Let's Encrypt** | Community | https://community.letsencrypt.org | Medium |
| **GitHub** | Email | support@github.com | Low |

---

## 🎯 Incident Severity Levels

### 🔴 P0 - CRITICAL (Response: Immediate)
- Complete service outage
- Payment processing down
- Data breach or security incident
- User data loss

### 🟠 P1 - HIGH (Response: <1 hour)
- Partial service outage (>25% users affected)
- Database performance degradation
- SSL certificate expired
- Major feature broken

### 🟡 P2 - MEDIUM (Response: <4 hours)
- Minor feature broken
- Performance degradation (<25% users)
- Non-critical API endpoint down

### 🟢 P3 - LOW (Response: <24 hours)
- UI bugs
- Non-critical monitoring alerts
- Documentation issues

---

## 🚨 Emergency Scenarios & Solutions

---

## 1️⃣ Complete Service Outage

**Symptoms:**
- API not responding (https://api.echoelmusic.com/health returns error)
- Users can't access app
- Monitoring shows all systems down

### 🔍 Diagnosis

```bash
# Check if server is reachable
ping YOUR_SERVER_IP

# SSH into server
ssh root@YOUR_SERVER_IP

# Check Docker containers
docker-compose ps

# Check system resources
htop
df -h
```

### 🛠️ Resolution Steps

#### Step 1: Check Server Status

```bash
# Is server running?
ping YOUR_SERVER_IP

# If no response → Go to Hetzner Console
# https://console.hetzner.cloud
# Check if server is powered on
```

#### Step 2: Restart Docker Containers

```bash
cd /root/echoelmusic/backend

# Stop containers
docker-compose down

# Check for errors
docker-compose logs

# Start containers
docker-compose up -d

# Wait 10 seconds
sleep 10

# Health check
curl http://localhost:3000/health
```

#### Step 3: If Still Down - Check Logs

```bash
# API logs
docker-compose logs api --tail=100

# Nginx logs
docker-compose logs nginx --tail=100

# System logs
tail -f /var/log/syslog
```

#### Step 4: Nuclear Option - Full Restart

```bash
# Restart Docker daemon
systemctl restart docker

# Restart all containers
cd /root/echoelmusic/backend
docker-compose down
docker-compose up -d

# Restart Nginx
systemctl restart nginx
```

### 📊 Post-Incident

- [ ] Document what caused the outage
- [ ] Update monitoring to catch this earlier
- [ ] Notify affected users (if >10 min downtime)
- [ ] Create post-mortem report

---

## 2️⃣ Database Connection Issues

**Symptoms:**
- API returns 500 errors
- `/api/health/db` endpoint failing
- Users can't login or save data

### 🔍 Diagnosis

```bash
# Test database connection
curl http://localhost:3000/api/health/db

# Check Supabase status
# Go to: https://status.supabase.com
```

### 🛠️ Resolution Steps

#### Step 1: Check Supabase Dashboard

1. Go to https://app.supabase.com
2. Check if project is paused (free tier auto-pauses after inactivity)
3. If paused → Click "Restore project"

#### Step 2: Verify Connection Credentials

```bash
cd /root/echoelmusic/backend

# Check .env file
cat .env | grep SUPABASE

# Make sure URL and keys are correct
```

#### Step 3: Test Direct Connection

```bash
# Install psql if needed
apt-get install -y postgresql-client

# Test connection (replace with your details)
psql "postgresql://postgres:[PASSWORD]@db.[PROJECT].supabase.co:5432/postgres"
```

#### Step 4: Check Connection Pool

**In Supabase Dashboard:**
- Go to Database → Connection Pooling
- Check if connection limit reached
- Restart pooler if needed

### 🔄 Rollback

```bash
# If all else fails, restart API to reset connections
docker-compose restart api
```

### 📊 Post-Incident

- [ ] Check if connection pool size is adequate
- [ ] Review slow queries
- [ ] Consider upgrading Supabase tier if hitting limits

---

## 3️⃣ Payment Processing Failure

**Symptoms:**
- Users can't subscribe
- Stripe webhooks failing
- Payment errors in logs

### 🔍 Diagnosis

```bash
# Check Stripe webhook endpoint
curl https://api.echoelmusic.com/webhooks/stripe

# Check API logs for Stripe errors
docker-compose logs api | grep -i stripe

# Go to Stripe Dashboard
# https://dashboard.stripe.com/webhooks
# Check webhook delivery status
```

### 🛠️ Resolution Steps

#### Step 1: Check Stripe Dashboard

1. Go to https://dashboard.stripe.com
2. Check if account is in restricted mode
3. Check webhook delivery logs
4. Verify webhook secret in `.env` matches Stripe

#### Step 2: Verify Stripe Keys

```bash
cd /root/echoelmusic/backend

# Check Stripe keys
cat .env | grep STRIPE

# Make sure using correct keys (live vs test)
# live keys: pk_live_... / sk_live_...
# test keys: pk_test_... / sk_test_...
```

#### Step 3: Test Webhook Endpoint

```bash
# Test webhook endpoint is accessible
curl -X POST https://api.echoelmusic.com/webhooks/stripe \
  -H "Content-Type: application/json" \
  -d '{"type":"test"}'
```

#### Step 4: Resend Failed Webhooks

1. Go to Stripe Dashboard → Webhooks
2. Find failed events
3. Click "Resend" for each failed event

### 🔄 Rollback

**If payments are completely broken:**

```bash
# Temporarily disable Stripe payments
nano /root/echoelmusic/backend/.env

# Change:
ENABLE_STRIPE_PAYMENTS=false

# Restart API
docker-compose restart api
```

**Notify users:**
- Post on status page
- Email affected users
- Offer alternative payment method or delay

### 📊 Post-Incident

- [ ] Document what failed
- [ ] Add monitoring for payment failures
- [ ] Consider implementing payment retry logic
- [ ] Refund affected users if needed

---

## 4️⃣ SSL Certificate Expired

**Symptoms:**
- Browser shows "Not Secure" warning
- Users can't access HTTPS site
- SSL Labs shows failed grade

### 🔍 Diagnosis

```bash
# Check certificate expiry
echo | openssl s_client -connect api.echoelmusic.com:443 2>/dev/null | openssl x509 -noout -dates

# Check Certbot status
certbot certificates
```

### 🛠️ Resolution Steps

#### Step 1: Renew Certificate Immediately

```bash
# Renew certificate
certbot renew --nginx --force-renewal

# Reload Nginx
nginx -s reload
```

#### Step 2: If Renewal Fails

```bash
# Stop Nginx temporarily
systemctl stop nginx

# Get new certificate
certbot certonly --standalone -d api.echoelmusic.com

# Start Nginx
systemctl start nginx
```

#### Step 3: Verify Renewal

```bash
# Check new expiry date
certbot certificates

# Test HTTPS
curl https://api.echoelmusic.com/health
```

#### Step 4: Setup Auto-Renewal (if missing)

```bash
# Add cron job
crontab -e

# Add this line:
0 5 1 * * certbot renew --nginx --quiet
```

### 📊 Post-Incident

- [ ] Verify auto-renewal is working
- [ ] Add monitoring for certificate expiry (30 days before)
- [ ] Document renewal process

---

## 5️⃣ Server Out of Disk Space

**Symptoms:**
- Services won't start
- Logs show "No space left on device"
- Can't upload files

### 🔍 Diagnosis

```bash
# Check disk usage
df -h

# Find largest directories
du -sh /* | sort -h

# Check Docker disk usage
docker system df
```

### 🛠️ Resolution Steps

#### Step 1: Clean Docker

```bash
# Remove unused containers, images, volumes
docker system prune -a --volumes

# This can free 1-5GB!
```

#### Step 2: Clean Logs

```bash
# Truncate large log files
truncate -s 0 /var/log/nginx/access.log
truncate -s 0 /var/log/nginx/error.log

# Clean Docker logs
docker-compose logs --tail=0

# Limit log size in docker-compose.yml
# (already configured in minimal setup)
```

#### Step 3: Remove Old Backups

```bash
# Remove backups older than 7 days
find /root/backups -name "*.sql" -mtime +7 -delete
find /root/backups -name "*.tar.gz" -mtime +7 -delete
```

#### Step 4: If Still Full - Upgrade Server

**Immediate fix:**
- Delete large files manually
- Move backups to S3

**Long-term:**
- Upgrade to server with more disk space
- Implement automatic log rotation

### 📊 Post-Incident

- [ ] Add disk space monitoring (alert at 80%)
- [ ] Setup log rotation
- [ ] Move backups to S3 automatically

---

## 6️⃣ High CPU/RAM Usage

**Symptoms:**
- Server unresponsive
- API slow (>1s response time)
- `htop` shows 100% CPU or RAM

### 🔍 Diagnosis

```bash
# Check resource usage
htop

# Check Docker stats
docker stats

# Find memory hogs
ps aux --sort=-%mem | head -10

# Find CPU hogs
ps aux --sort=-%cpu | head -10
```

### 🛠️ Resolution Steps

#### Step 1: Identify Problem Container

```bash
docker stats

# Note which container is using too much CPU/RAM
```

#### Step 2: Restart Problem Container

```bash
cd /root/echoelmusic/backend

# Restart specific container
docker-compose restart api

# Or restart all
docker-compose restart
```

#### Step 3: Check for Memory Leaks

```bash
# Check API logs for errors
docker-compose logs api | grep -i error

# Check for infinite loops or stuck processes
```

#### Step 4: If Nothing Helps - Reboot Server

```bash
# ⚠️ WARNING: This will cause 2-5 min downtime!

# Graceful shutdown
docker-compose down
systemctl stop nginx

# Reboot
reboot

# After reboot, SSH back in and start services
cd /root/echoelmusic/backend
docker-compose up -d
```

### 🔄 Rollback

**If server is critically low on resources:**

```bash
# Temporarily scale down
docker-compose scale api=1

# Or stop non-critical services
docker stop echoelmusic-worker
```

### 📊 Post-Incident

- [ ] Identify root cause (memory leak? infinite loop?)
- [ ] Optimize code if needed
- [ ] Consider upgrading server (CX11 → CX21)
- [ ] Add resource monitoring alerts

---

## 7️⃣ Failed Deployment / Code Rollback

**Symptoms:**
- Deployment broke the app
- New code has critical bug
- Need to revert to previous version

### 🔍 Diagnosis

```bash
# Check what changed
git log -5

# Check current running version
docker-compose ps
docker-compose logs api | head -20
```

### 🛠️ Resolution Steps - ROLLBACK

#### Step 1: Stop Current Deployment

```bash
cd /root/echoelmusic/backend
docker-compose down
```

#### Step 2: Revert Code to Last Working Version

```bash
# See recent commits
git log --oneline -10

# Identify last working commit (e.g., abc123)
# Rollback to that commit
git reset --hard abc123

# Or go back one commit
git reset --hard HEAD~1
```

#### Step 3: Rebuild with Old Code

```bash
# Clear old images
docker-compose build --no-cache

# Start containers
docker-compose up -d

# Wait and test
sleep 10
curl http://localhost:3000/health
```

#### Step 4: Verify Rollback Success

```bash
# Check API is responding
curl https://api.echoelmusic.com/health

# Check logs for errors
docker-compose logs api | grep -i error

# Check user-facing app still works
```

### 📊 Post-Incident

- [ ] Document what broke in new deployment
- [ ] Fix issue in separate branch
- [ ] Test thoroughly before re-deploying
- [ ] Consider staging environment

---

## 8️⃣ Data Breach / Security Incident

**Symptoms:**
- Suspicious login attempts
- Unauthorized database access
- User reports compromised account

### 🚨 IMMEDIATE ACTIONS (P0 - Critical)

#### Step 1: STOP THE LEAK

```bash
# Immediately take API offline
cd /root/echoelmusic/backend
docker-compose down

# Block all access
ufw deny 80
ufw deny 443
```

#### Step 2: Assess Damage

```bash
# Check access logs for suspicious IPs
cat /var/log/nginx/access.log | grep -E "POST|PUT|DELETE"

# Check database for unauthorized queries
# (Supabase Dashboard → Logs)

# Check if .env was compromised
ls -la /root/echoelmusic/backend/.env
```

#### Step 3: Rotate ALL Credentials IMMEDIATELY

**Supabase:**
1. Go to Supabase Dashboard
2. Settings → API
3. Regenerate all API keys

**Stripe:**
1. Go to Stripe Dashboard
2. Developers → API Keys
3. Roll secret key

**JWT Secret:**
```bash
# Generate new JWT secret
openssl rand -hex 32

# Update .env
nano /root/echoelmusic/backend/.env
```

**Database Password:**
1. Supabase Dashboard → Settings → Database
2. Reset password

#### Step 4: Notify Users

**Immediately notify all users:**
- Email all users about potential breach
- Force password reset for all accounts
- Explain what happened and what you're doing

#### Step 5: Report to Authorities (DSGVO Requirement!)

**⚠️ LEGAL REQUIREMENT in EU:**

If personal data was compromised, you MUST:
1. Notify data protection authority within 72 hours
2. Germany: https://www.bfdi.bund.de
3. Notify affected users

### 🛠️ Recovery Steps

```bash
# 1. Update all credentials in .env
nano /root/echoelmusic/backend/.env

# 2. Force all users to re-login
# (Invalidate all JWT tokens in database)

# 3. Review and patch security vulnerability

# 4. Restart services with new credentials
docker-compose up -d
```

### 📊 Post-Incident

- [ ] Full security audit
- [ ] Pen-testing
- [ ] Review access logs
- [ ] Implement additional security measures
- [ ] Create incident report for authorities
- [ ] Consider hiring security consultant

---

## 9️⃣ GitHub Actions Deployment Failed

**Symptoms:**
- GitHub Actions workflow failing
- Auto-deployment not working
- Build errors

### 🔍 Diagnosis

```bash
# Check GitHub Actions logs
# Go to: https://github.com/vibrationalforce/Echoelmusic/actions

# Check latest workflow run
# Read error messages
```

### 🛠️ Resolution Steps

#### Step 1: Check Secrets

1. Go to GitHub → Settings → Secrets and variables → Actions
2. Verify all secrets are set:
   - `SSH_PRIVATE_KEY`
   - `DEPLOY_SERVER_IP`
   - `DOMAIN`
   - etc.

#### Step 2: Test SSH Connection

```bash
# On your local machine, test SSH
ssh root@YOUR_SERVER_IP

# If fails, regenerate SSH keys and add to GitHub secrets
```

#### Step 3: Manual Deployment

**If GitHub Actions broken, deploy manually:**

```bash
# SSH into server
ssh root@YOUR_SERVER_IP

# Pull latest code
cd /root/Echoelmusic
git pull origin main

# Redeploy
cd backend
docker-compose down
docker-compose build
docker-compose up -d
```

#### Step 4: Fix Workflow

- Fix errors in `.github/workflows/deploy-backend.yml`
- Test locally if possible
- Push fix and trigger workflow again

### 📊 Post-Incident

- [ ] Add workflow tests
- [ ] Setup notifications for failed workflows
- [ ] Document manual deployment process

---

## 🔄 General Rollback Procedure

**Use this when any deployment breaks production:**

### 1️⃣ Stop Current Version

```bash
cd /root/echoelmusic/backend
docker-compose down
```

### 2️⃣ Backup Current State (Just in Case)

```bash
cp -r /root/echoelmusic/backend /root/echoelmusic/backend-backup-$(date +%Y%m%d_%H%M%S)
```

### 3️⃣ Revert Code

```bash
# Go to last known good commit
git log --oneline -10

# Reset to specific commit
git reset --hard COMMIT_HASH

# Or go back one commit
git reset --hard HEAD~1
```

### 4️⃣ Rebuild & Deploy

```bash
docker-compose build --no-cache
docker-compose up -d
```

### 5️⃣ Verify

```bash
sleep 10
curl http://localhost:3000/health
curl https://api.echoelmusic.com/health
```

### 6️⃣ Notify

- Update status page
- Notify users if there was downtime
- Post-mortem: What went wrong?

---

## 📋 Emergency Checklists

### 🔴 Critical Incident Response

- [ ] **0-2 min:** Assess severity (P0/P1/P2/P3)
- [ ] **2-5 min:** Identify root cause
- [ ] **5-10 min:** Implement immediate fix or rollback
- [ ] **10-15 min:** Verify fix works
- [ ] **15-30 min:** Monitor for recurring issues
- [ ] **30-60 min:** Notify affected users
- [ ] **24 hours:** Post-mortem and prevention plan

### 🟠 Deployment Rollback

- [ ] Stop current deployment
- [ ] Backup current state
- [ ] Identify last working commit
- [ ] Revert code to last working version
- [ ] Rebuild containers
- [ ] Start services
- [ ] Health check
- [ ] Notify users
- [ ] Fix issue before re-deploying

### 🔒 Security Incident

- [ ] **IMMEDIATE:** Stop the leak (take services offline if needed)
- [ ] Assess damage (what was compromised?)
- [ ] Rotate ALL credentials
- [ ] Patch vulnerability
- [ ] Notify users
- [ ] Notify authorities (if personal data breached)
- [ ] Full security audit
- [ ] Implement prevention measures

---

## 📊 Post-Incident Template

**Copy this template after every P0/P1 incident:**

```markdown
# Incident Report: [SHORT TITLE]

**Date:** YYYY-MM-DD
**Duration:** XX minutes
**Severity:** P0 / P1 / P2
**Users Affected:** ~XXX users

## Summary
[One paragraph description of what happened]

## Timeline
- HH:MM - Incident detected
- HH:MM - Root cause identified
- HH:MM - Fix implemented
- HH:MM - Incident resolved

## Root Cause
[Technical explanation of what caused the issue]

## Impact
- Downtime: XX minutes
- Users affected: ~XXX
- Data loss: Yes/No
- Financial impact: €XXX

## Resolution
[What was done to fix it]

## Prevention
[What will be done to prevent this in future]

## Action Items
- [ ] Item 1
- [ ] Item 2
- [ ] Item 3

## Lessons Learned
[Key takeaways]
```

---

## 🛠️ Useful Commands Reference

### Quick Diagnostics

```bash
# Server health
df -h                           # Disk space
htop                            # CPU/RAM
docker stats                    # Container resources
docker-compose ps               # Container status

# Service health
curl http://localhost:3000/health
curl https://api.echoelmusic.com/health
systemctl status nginx
systemctl status docker

# Logs
docker-compose logs -f
tail -f /var/log/nginx/error.log
journalctl -xe
```

### Quick Fixes

```bash
# Restart everything
cd /root/echoelmusic/backend
docker-compose restart

# Restart specific service
docker-compose restart api
systemctl restart nginx

# Full rebuild
docker-compose down
docker-compose build --no-cache
docker-compose up -d

# Clean Docker
docker system prune -a

# Rollback one commit
git reset --hard HEAD~1
docker-compose down
docker-compose build
docker-compose up -d
```

---

## 📞 When to Escalate

### Contact Hetzner Support If:
- Server hardware failure
- Network issues
- Can't access server remotely
- DDoS attack

### Contact Supabase Support If:
- Database unresponsive >15 min
- Data corruption
- Backup restore needed
- Unexpected billing

### Contact Stripe Support If:
- Payment processing down >30 min
- Account restricted
- Webhook issues persist
- Fraud detection issues

---

## 🎯 Prevention Checklist

**Implement these to reduce incidents:**

- [ ] Setup automated backups (daily)
- [ ] Monitor disk space (alert at 80%)
- [ ] Monitor uptime (UptimeRobot)
- [ ] Monitor errors (Sentry)
- [ ] Setup SSL expiry alerts (30 days before)
- [ ] Document all procedures
- [ ] Regular security audits
- [ ] Staging environment for testing
- [ ] Automated testing before deployment
- [ ] Rate limiting on all endpoints
- [ ] Regular dependency updates
- [ ] Disaster recovery plan tested quarterly

---

## 📚 Additional Resources

**Internal Docs:**
- `PRODUCTION_CHECKLIST.md` - Pre-deployment checks
- `BROWSER_ONLY_DEPLOY.md` - Deployment guide
- `QUICK_START_COMMANDS.md` - Command reference

**External Resources:**
- **Docker:** https://docs.docker.com/engine/reference/commandline/docker/
- **Nginx:** https://nginx.org/en/docs/
- **Let's Encrypt:** https://letsencrypt.org/docs/
- **Supabase Status:** https://status.supabase.com
- **Stripe Status:** https://status.stripe.com

---

**Remember:** Stay calm, follow procedures, and document everything!

**Status:** 🚨 Emergency Procedures Active

**Last Updated:** November 15, 2024

---

🎵 **Echoelmusic** - Always Ready for Production

© 2024 Echoel (Michael Terbuyken) | Hamburg, Germany
