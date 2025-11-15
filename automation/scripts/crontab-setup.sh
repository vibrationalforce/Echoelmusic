#!/bin/bash
#
# Crontab Setup Script
# Sets up automated cron jobs for maintenance tasks
#
# Usage: ./crontab-setup.sh [environment]
# Example: ./crontab-setup.sh production
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
ENVIRONMENT=${1:-production}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}[INFO]${NC} Setting up cron jobs for ${ENVIRONMENT}..."

# Create temporary crontab file
TEMP_CRON=$(mktemp)

# Add existing crontab entries
crontab -l > $TEMP_CRON 2>/dev/null || true

# Remove old Echoelmusic entries
sed -i '/# Echoelmusic/d' $TEMP_CRON
sed -i '/echoelmusic/d' $TEMP_CRON

# Add header
echo "" >> $TEMP_CRON
echo "# Echoelmusic Automation Tasks (${ENVIRONMENT})" >> $TEMP_CRON
echo "# Generated on $(date)" >> $TEMP_CRON
echo "" >> $TEMP_CRON

#
# Daily Backups (2 AM)
#
echo "# Daily database backup at 2 AM" >> $TEMP_CRON
echo "0 2 * * * ${SCRIPT_DIR}/database-backup.sh ${ENVIRONMENT} >> /var/log/echoelmusic/backup.log 2>&1" >> $TEMP_CRON
echo "" >> $TEMP_CRON

#
# Health Checks (Every 5 minutes)
#
echo "# Health check every 5 minutes" >> $TEMP_CRON
echo "*/5 * * * * ${SCRIPT_DIR}/health-check.sh ${ENVIRONMENT} >> /var/log/echoelmusic/health.log 2>&1" >> $TEMP_CRON
echo "" >> $TEMP_CRON

#
# Security Updates (Weekly - Monday 3 AM)
#
if [ "$ENVIRONMENT" == "production" ]; then
  # Production: Manual approval required
  echo "# Security update check (manual) every Monday at 3 AM" >> $TEMP_CRON
  echo "0 3 * * 1 ${SCRIPT_DIR}/security-updates.sh ${ENVIRONMENT} false >> /var/log/echoelmusic/security.log 2>&1" >> $TEMP_CRON
else
  # Staging: Auto-apply
  echo "# Security update check (auto) every Monday at 3 AM" >> $TEMP_CRON
  echo "0 3 * * 1 ${SCRIPT_DIR}/security-updates.sh ${ENVIRONMENT} true >> /var/log/echoelmusic/security.log 2>&1" >> $TEMP_CRON
fi
echo "" >> $TEMP_CRON

#
# Analytics Report (Weekly - Monday 9 AM)
#
echo "# Weekly analytics report every Monday at 9 AM" >> $TEMP_CRON
echo "0 9 * * 1 cd ${SCRIPT_DIR}/../marketing && node analytics-tracking.js weekly >> /var/log/echoelmusic/analytics.log 2>&1" >> $TEMP_CRON
echo "" >> $TEMP_CRON

#
# Social Media Content (Daily - 8 AM)
#
echo "# Check and schedule social media content daily at 8 AM" >> $TEMP_CRON
echo "0 8 * * * cd ${SCRIPT_DIR}/../marketing && node social-media-automation.js schedule >> /var/log/echoelmusic/social.log 2>&1" >> $TEMP_CRON
echo "" >> $TEMP_CRON

#
# Log Rotation (Daily - Midnight)
#
echo "# Rotate logs daily at midnight" >> $TEMP_CRON
echo "0 0 * * * find /var/log/echoelmusic/*.log -mtime +30 -delete >> /var/log/echoelmusic/cleanup.log 2>&1" >> $TEMP_CRON
echo "" >> $TEMP_CRON

#
# Docker Cleanup (Weekly - Sunday 4 AM)
#
echo "# Clean up old Docker images every Sunday at 4 AM" >> $TEMP_CRON
echo "0 4 * * 0 docker system prune -af --filter 'until=720h' >> /var/log/echoelmusic/docker-cleanup.log 2>&1" >> $TEMP_CRON
echo "" >> $TEMP_CRON

#
# SSL Certificate Renewal (Monthly - 1st at 5 AM)
#
if [ "$ENVIRONMENT" == "production" ]; then
  echo "# Renew SSL certificates monthly on the 1st at 5 AM" >> $TEMP_CRON
  echo "0 5 1 * * certbot renew --nginx >> /var/log/echoelmusic/certbot.log 2>&1" >> $TEMP_CRON
  echo "" >> $TEMP_CRON
fi

#
# Restart Services (Weekly - Sunday 3 AM)
#
echo "# Restart services weekly on Sunday at 3 AM (low traffic)" >> $TEMP_CRON
echo "0 3 * * 0 cd /opt/echoelmusic && docker-compose restart >> /var/log/echoelmusic/restart.log 2>&1" >> $TEMP_CRON
echo "" >> $TEMP_CRON

# Show what will be installed
echo -e "${BLUE}[INFO]${NC} Cron jobs to be installed:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat $TEMP_CRON
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Confirm installation
read -p "$(echo -e ${YELLOW}Install these cron jobs? [y/N]: ${NC})" -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
  # Install crontab
  crontab $TEMP_CRON

  echo -e "${GREEN}[SUCCESS]${NC} Cron jobs installed successfully!"

  # Create log directory
  sudo mkdir -p /var/log/echoelmusic
  sudo chown -R $USER:$USER /var/log/echoelmusic

  echo -e "${GREEN}[SUCCESS]${NC} Log directory created: /var/log/echoelmusic"

  # Make scripts executable
  chmod +x ${SCRIPT_DIR}/*.sh

  echo -e "${GREEN}[SUCCESS]${NC} Scripts made executable"

  # Show installed crontab
  echo ""
  echo -e "${BLUE}[INFO]${NC} Current crontab:"
  crontab -l

  # Send notification
  if [ -n "$SLACK_WEBHOOK" ]; then
    curl -X POST -H 'Content-type: application/json' \
      --data "{\"text\":\"✅ Cron jobs configured for Echoelmusic ${ENVIRONMENT}\"}" \
      $SLACK_WEBHOOK
  fi
else
  echo -e "${YELLOW}[INFO]${NC} Installation cancelled"
fi

# Clean up
rm -f $TEMP_CRON

echo ""
echo -e "${GREEN}[SUCCESS]${NC} Cron setup complete!"
echo ""
echo -e "${BLUE}[INFO]${NC} Scheduled tasks:"
echo "  • Database backups: Daily at 2 AM"
echo "  • Health checks: Every 5 minutes"
echo "  • Security updates: Weekly (Monday 3 AM)"
echo "  • Analytics reports: Weekly (Monday 9 AM)"
echo "  • Social media: Daily at 8 AM"
echo "  • Log rotation: Daily at midnight"
echo "  • Docker cleanup: Weekly (Sunday 4 AM)"
if [ "$ENVIRONMENT" == "production" ]; then
  echo "  • SSL renewal: Monthly (1st at 5 AM)"
fi
echo "  • Service restart: Weekly (Sunday 3 AM)"
echo ""
echo -e "${BLUE}[INFO]${NC} Logs location: /var/log/echoelmusic/"
echo ""

exit 0
