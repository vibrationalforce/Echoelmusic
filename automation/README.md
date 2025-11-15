# 🤖 Echoelmusic Automation Infrastructure

**Complete automation system for 95% automated operations**

---

## 📂 DIRECTORY STRUCTURE

```
automation/
├── README.md                          # This file
├── deploy.sh                          # Main deployment script
├── scripts/                           # Maintenance scripts
│   ├── crontab-setup.sh              # Setup automated cron jobs
│   ├── database-backup.sh            # Daily database backups
│   ├── database-restore.sh           # Restore from backup
│   ├── health-check.sh               # System health monitoring
│   └── security-updates.sh           # Automated security updates
├── marketing/                         # Marketing automation
│   ├── email-templates.json          # Email campaign templates
│   ├── content-calendar-template.json # Social media content calendar
│   ├── social-media-automation.js    # Buffer integration
│   └── analytics-tracking.js         # Mixpanel integration
├── support/                           # Customer support automation
│   └── knowledge-base.json           # 50+ help articles
└── dashboard/                         # Analytics dashboard
    └── analytics-dashboard.html      # Real-time metrics dashboard
```

---

## 🚀 QUICK START

### Prerequisites

```bash
# Install dependencies
npm install axios mixpanel @supabase/supabase-js

# Set environment variables
export MIXPANEL_TOKEN=xxx
export SUPABASE_URL=xxx
export SUPABASE_SERVICE_KEY=xxx
export BUFFER_API_KEY=xxx
export SLACK_WEBHOOK=xxx
```

### Deploy Backend

```bash
# From project root
cd backend

# Build and deploy to production
../automation/deploy.sh production v1.0.0
```

### Setup Cron Jobs

```bash
# On your server
cd automation/scripts
./crontab-setup.sh production
```

---

## 📋 SCRIPTS REFERENCE

### Deployment

**`deploy.sh`** - Main deployment script
```bash
# Deploy to staging
./automation/deploy.sh staging v1.2.3

# Deploy to production (requires confirmation)
./automation/deploy.sh production v1.2.3

# Rollback
./automation/deploy.sh production rollback
```

**Features:**
- ✅ Validates environment
- ✅ Runs tests
- ✅ Builds Docker images
- ✅ Deploys to servers
- ✅ Runs migrations
- ✅ Health checks
- ✅ Auto-rollback on failure
- ✅ Slack notifications

---

### Database Management

**`database-backup.sh`** - Automated backups
```bash
./automation/scripts/database-backup.sh production
```

**Features:**
- Dumps PostgreSQL database
- Compresses with gzip
- Uploads to S3
- Retains 30 days on S3
- Cleans up old backups

**`database-restore.sh`** - Restore from backup
```bash
./automation/scripts/database-restore.sh production backup_file.sql.gz
```

**Features:**
- Creates pre-restore backup
- Downloads from S3
- Restores database
- Runs migrations
- Optimizes database

**Safety:**
- Requires explicit confirmation for production
- Creates automatic rollback point
- Validates backup before restore

---

### Monitoring

**`health-check.sh`** - System health monitoring
```bash
./automation/scripts/health-check.sh production
```

**Checks:**
- API response time (< 2000ms)
- Database connectivity
- Redis connectivity
- CPU usage (< 80%)
- Memory usage (< 85%)
- Disk usage (< 90%)
- Docker containers status
- SSL certificate expiry

**Alerts:**
- Slack notifications
- Email alerts (SendGrid)
- Exit code 1 on failure (for cron)

**Cron Schedule:** Every 5 minutes
```
*/5 * * * * /opt/echoelmusic/automation/scripts/health-check.sh production
```

---

### Security

**`security-updates.sh`** - Automated security updates
```bash
# Check only (no changes)
./automation/scripts/security-updates.sh production false

# Auto-apply updates
./automation/scripts/security-updates.sh production true
```

**Features:**
- Scans npm packages for vulnerabilities
- Checks Docker base images
- Monitors system packages
- Updates SSL certificates
- GitHub security advisories

**Auto-fix (staging):**
- Applies npm security fixes
- Runs tests
- Deploys if tests pass
- Rolls back if tests fail

**Cron Schedule:** Weekly (Monday 3 AM)
```
0 3 * * 1 /opt/echoelmusic/automation/scripts/security-updates.sh production
```

---

### Cron Setup

**`crontab-setup.sh`** - Configure all automated tasks
```bash
./automation/scripts/crontab-setup.sh production
```

**Scheduled Tasks:**

| Task | Schedule | Description |
|------|----------|-------------|
| Database Backup | Daily 2 AM | Full database backup to S3 |
| Health Check | Every 5 min | Monitor system health |
| Security Updates | Mon 3 AM | Check and apply security patches |
| Analytics Report | Mon 9 AM | Weekly metrics email |
| Social Media | Daily 8 AM | Schedule posts to Buffer |
| Log Rotation | Daily 12 AM | Delete logs older than 30 days |
| Docker Cleanup | Sun 4 AM | Remove old images/containers |
| SSL Renewal | 1st 5 AM | Renew Let's Encrypt certificates |
| Service Restart | Sun 3 AM | Weekly service restart |

---

## 📧 MARKETING AUTOMATION

### Email Campaigns

**Location:** `automation/marketing/email-templates.json`

**Campaigns:**
- Welcome Series (Day 0, 2, 7)
- Trial Nurture (Day -3, 0, +7)
- Feature Announcements
- Project Milestones (10, 50, 100 projects)

**Integration:**
```javascript
// In your backend
const templates = require('./automation/marketing/email-templates.json');

// Send welcome email
await sendEmail({
  to: user.email,
  subject: templates.emailTemplates.welcome.subject,
  body: templates.emailTemplates.welcome.body.replace('{{name}}', user.name)
});
```

---

### Social Media

**Script:** `automation/marketing/social-media-automation.js`

**Usage:**
```bash
# Generate 30 days of content
node social-media-automation.js generate

# Schedule posts to Buffer
BUFFER_API_KEY=xxx node social-media-automation.js schedule

# Monitor mentions
node social-media-automation.js monitor
```

**Features:**
- Auto-generates content calendar
- Schedules to Buffer (Twitter, Instagram, TikTok, LinkedIn)
- Optimal posting times per platform
- Content mix: 25% features, 35% tutorials, 25% showcases, 15% BTS

**Content Calendar:** `automation/marketing/content-calendar-template.json`

---

### Analytics

**Script:** `automation/marketing/analytics-tracking.js`

**Usage:**
```bash
# Generate weekly report
node analytics-tracking.js weekly

# Generate custom period report
node analytics-tracking.js metrics 2025-01-01 2025-01-31
```

**Metrics Tracked:**
- Total Users, MAU, DAU
- MRR, ARR, ARPU
- Conversion Rate
- Churn Rate
- Total Projects
- Feature Usage
- Conversion Funnel

**Integration:**
```javascript
const AnalyticsTracking = require('./automation/marketing/analytics-tracking.js');

const analytics = new AnalyticsTracking({
  mixpanelToken: process.env.MIXPANEL_TOKEN,
  supabaseUrl: process.env.SUPABASE_URL,
  supabaseKey: process.env.SUPABASE_SERVICE_KEY
});

// Track user signup
analytics.trackSignup(userId, {
  email: user.email,
  platform: 'iOS'
});

// Track project creation
analytics.trackProjectCreated(userId, {
  type: 'Audio',
  template: 'Electronic Production'
});
```

---

## 🆘 CUSTOMER SUPPORT

### Knowledge Base

**Location:** `automation/support/knowledge-base.json`

**Features:**
- 50+ articles
- 4 categories (Getting Started, Account, Troubleshooting, Features)
- Searchable by keywords
- Related articles linking

**Integration:**
```javascript
// Load knowledge base
const kb = require('./automation/support/knowledge-base.json');

// Search articles
function searchKB(query) {
  return kb.knowledgeBase.categories.flatMap(cat =>
    cat.articles.filter(article =>
      article.keywords.some(kw => kw.includes(query.toLowerCase()))
    )
  );
}

// Get article by ID
function getArticle(id) {
  return kb.knowledgeBase.categories
    .flatMap(cat => cat.articles)
    .find(article => article.id === id);
}
```

**Deployment:**
- Host on help.echoelmusic.com
- Integrate with Intercom AI chatbot
- In-app search (Settings → Help)

**Expected Results:**
- 70-80% auto-resolution
- 20-30% escalation to email
- <5% need human response

---

## 📊 ANALYTICS DASHBOARD

**Location:** `automation/dashboard/analytics-dashboard.html`

**Access:** https://api.echoelmusic.com/dashboard (password protected)

**Metrics:**
- Total Users, MAU
- MRR, ARR, ARPU
- Conversion Rate, Churn Rate
- Total Projects

**Charts:**
- User Growth (30 days)
- Revenue Breakdown (Free/Pro/Studio)
- MRR History (6 months)
- Feature Usage
- Project Activity (7 days)
- Conversion Funnel

**Auto-refresh:** Every 5 minutes

**Setup:**
1. Upload HTML to server
2. Configure Nginx with basic auth
3. Ensure backend analytics API endpoint is running

---

## 🔧 TROUBLESHOOTING

### Deployment Issues

**Problem:** Deployment fails at health check
```bash
# Check logs
ssh deploy@api.echoelmusic.com
docker-compose logs -f api

# Manual health check
curl https://api.echoelmusic.com/health

# Restart services
docker-compose restart

# Rollback
./automation/deploy.sh production rollback
```

**Problem:** Migration fails
```bash
# Check migration status
npm run migrate:status

# Rollback last migration
npm run migrate:rollback

# Re-run migrations
npm run migrate
```

---

### Backup/Restore Issues

**Problem:** Backup fails to upload to S3
```bash
# Check AWS credentials
aws s3 ls s3://echoelmusic-backups

# Manual upload
aws s3 cp backup.sql.gz s3://echoelmusic-backups/production/

# Check IAM permissions (needs s3:PutObject, s3:GetObject, s3:DeleteObject)
```

**Problem:** Restore fails
```bash
# Verify backup file exists
aws s3 ls s3://echoelmusic-backups/production/

# Test pg_restore locally
pg_restore --list backup.sql

# Check database connection
psql "${SUPABASE_DATABASE_URL}" -c "SELECT 1"
```

---

### Health Check Alerts

**Problem:** High CPU usage
```bash
# Check running processes
top -b -n 1

# Check Docker container stats
docker stats

# Restart high-usage containers
docker-compose restart api

# Scale horizontally if needed
```

**Problem:** API slow response times
```bash
# Check database query performance
# In Supabase dashboard → SQL Editor
SELECT * FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 10;

# Add indexes if needed
CREATE INDEX idx_projects_user_id ON projects(user_id);

# Check Redis connection
redis-cli ping
```

---

### Marketing Automation Issues

**Problem:** Emails not sending
```bash
# Check SendGrid API key
curl -X POST https://api.sendgrid.com/v3/mail/send \
  -H "Authorization: Bearer $SENDGRID_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"personalizations":[{"to":[{"email":"test@example.com"}]}],"from":{"email":"hello@echoelmusic.com"},"subject":"Test","content":[{"type":"text/plain","value":"Test"}]}'

# Check domain authentication in SendGrid dashboard
# Verify SPF, DKIM records in DNS
```

**Problem:** Social media posts not scheduling
```bash
# Check Buffer API connection
curl -X GET "https://api.bufferapp.com/1/user.json?access_token=$BUFFER_API_KEY"

# Check profile IDs
curl -X GET "https://api.bufferapp.com/1/profiles.json?access_token=$BUFFER_API_KEY"

# Manual test post
node social-media-automation.js schedule content-calendar-test.json
```

---

## 📈 SUCCESS METRICS

### Target Performance

- ✅ **Build Success Rate**: >95%
- ✅ **Deployment Time**: <10 minutes
- ✅ **Support Auto-Resolution**: 70-80%
- ✅ **Marketing Scheduled**: 30 days ahead
- ✅ **API Response Time**: <500ms (p95)
- ✅ **Uptime**: >99.5%
- ✅ **Backup Success Rate**: 100%

### Actual Performance (Expected)

- 🎯 Builds: 97% success (3% failed tests)
- 🎯 Deployments: 8 min average
- 🎯 Support: 75% auto-resolved
- 🎯 Content: 45 days scheduled
- 🎯 API: 320ms average response
- 🎯 Uptime: 99.8%
- 🎯 Backups: 100% success

---

## 💰 COST BREAKDOWN

### Monthly Operational Costs

**Infrastructure:**
- Server (4GB RAM): €10-20
- Supabase: €0-25 (scales with usage)
- AWS S3: €10-50 (storage + CDN)
- Redis Cloud: €0-10
- **Subtotal: €20-105/month**

**Automation Tools:**
- GitHub Actions: €0 (free tier)
- Mailchimp: €0-30 (2,000 contacts free)
- Buffer: €15
- Intercom: €50
- Stripe: €0 (2.9% per transaction)
- Mixpanel: €0-50
- Sentry: €26
- UptimeRobot: €0 (free tier)
- **Subtotal: €91-171/month**

**Total: €111-276/month** (scales with usage)

---

## ⏱️ TIME INVESTMENT

### One-Time Setup
- CI/CD Configuration: 8 hours
- Backend Infrastructure: 12 hours
- Support Automation: 6 hours
- Marketing Automation: 8 hours
- Dashboard Setup: 4 hours
- **Total: ~38 hours**

### Ongoing Maintenance
- Review support tickets: 30 min/week
- Check analytics: 30 min/week
- Deploy updates: 30 min/week
- Create social content: 1 hour/week
- **Total: 2.5-3 hours/week**

---

## 📚 DOCUMENTATION

### Available Guides

1. **[AUTOMATION_GUIDE.md](../AUTOMATION_GUIDE.md)**
   - Complete overview of all automation systems
   - Usage instructions
   - Troubleshooting

2. **[AUTOMATION_SETUP_GUIDE.md](../AUTOMATION_SETUP_GUIDE.md)**
   - Step-by-step setup instructions
   - Certificate generation
   - Account configuration
   - Deployment procedures

3. **[LEGAL_BUSINESS_ANALYSIS.md](../LEGAL_BUSINESS_ANALYSIS.md)**
   - Legal compliance analysis
   - Business strategy
   - Market compatibility

4. **Backend API Documentation**
   - See `backend/README.md`
   - API endpoints reference
   - Database schema

---

## 🆘 SUPPORT

**Questions about automation?**
- 📧 Email: hello@echoelmusic.com
- 💬 Discord: discord.gg/echoelmusic
- 📖 Documentation: docs.echoelmusic.com
- 🐛 Issues: github.com/vibrationalforce/Echoelmusic/issues

---

## ✅ QUICK REFERENCE

### Essential Commands

```bash
# Deploy to production
./automation/deploy.sh production v1.0.0

# Create database backup
./automation/scripts/database-backup.sh production

# Check system health
./automation/scripts/health-check.sh production

# Generate analytics report
cd automation/marketing && node analytics-tracking.js weekly

# Schedule social media content
cd automation/marketing && node social-media-automation.js schedule

# Setup all cron jobs
cd automation/scripts && ./crontab-setup.sh production
```

### Important URLs

- **API**: https://api.echoelmusic.com
- **Dashboard**: https://api.echoelmusic.com/dashboard
- **Help Center**: https://help.echoelmusic.com
- **Staging**: https://staging.echoelmusic.com

### Emergency Contacts

- **Primary**: hello@echoelmusic.com
- **Alerts**: Check Slack webhook notifications
- **Monitoring**: UptimeRobot, Sentry

---

**Last Updated**: November 15, 2024
**Version**: 1.0.0
**Maintained by**: Michael Terbuyken (Echoel)
**License**: Proprietary
