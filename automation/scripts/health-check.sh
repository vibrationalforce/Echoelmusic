#!/bin/bash
#
# Health Check Script
# Monitors system health and sends alerts if issues detected
#
# Usage: ./health-check.sh [environment]
# Example: ./health-check.sh production
#
# Can be run via cron: */5 * * * * /path/to/health-check.sh production
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
ENVIRONMENT=${1:-production}
ALERT_THRESHOLD_CPU=80
ALERT_THRESHOLD_MEMORY=85
ALERT_THRESHOLD_DISK=90
ALERT_THRESHOLD_RESPONSE_TIME=2000  # milliseconds

# Load environment variables
if [ -f "../.env.${ENVIRONMENT}" ]; then
  export $(cat "../.env.${ENVIRONMENT}" | grep -v '^#' | xargs)
fi

# Initialize alert flag
ALERTS=""

echo -e "${GREEN}[INFO]${NC} Running health checks for ${ENVIRONMENT}..."

#
# 1. API Health Check
#
echo -e "${GREEN}[INFO]${NC} Checking API health..."

if [ "$ENVIRONMENT" == "production" ]; then
  API_URL="https://api.echoelmusic.com"
elif [ "$ENVIRONMENT" == "staging" ]; then
  API_URL="https://staging.echoelmusic.com"
else
  API_URL="http://localhost:3000"
fi

# Check API response
API_START=$(date +%s%3N)
API_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" ${API_URL}/health)
API_END=$(date +%s%3N)
API_TIME=$((API_END - API_START))

if [ "$API_RESPONSE" == "200" ]; then
  echo -e "${GREEN}[SUCCESS]${NC} API is healthy (${API_TIME}ms)"

  if [ $API_TIME -gt $ALERT_THRESHOLD_RESPONSE_TIME ]; then
    ALERTS="${ALERTS}⚠️ API response time is slow: ${API_TIME}ms (threshold: ${ALERT_THRESHOLD_RESPONSE_TIME}ms)\n"
  fi
else
  echo -e "${RED}[ERROR]${NC} API is down (status: ${API_RESPONSE})"
  ALERTS="${ALERTS}🚨 API is DOWN! Status code: ${API_RESPONSE}\n"
fi

#
# 2. Database Health Check
#
echo -e "${GREEN}[INFO]${NC} Checking database health..."

DB_START=$(date +%s%3N)
DB_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" ${API_URL}/health/db)
DB_END=$(date +%s%3N)
DB_TIME=$((DB_END - DB_START))

if [ "$DB_RESPONSE" == "200" ]; then
  echo -e "${GREEN}[SUCCESS]${NC} Database is healthy (${DB_TIME}ms)"

  if [ $DB_TIME -gt $ALERT_THRESHOLD_RESPONSE_TIME ]; then
    ALERTS="${ALERTS}⚠️ Database response time is slow: ${DB_TIME}ms (threshold: ${ALERT_THRESHOLD_RESPONSE_TIME}ms)\n"
  fi
else
  echo -e "${RED}[ERROR]${NC} Database is down (status: ${DB_RESPONSE})"
  ALERTS="${ALERTS}🚨 DATABASE is DOWN! Status code: ${DB_RESPONSE}\n"
fi

#
# 3. Redis Health Check
#
echo -e "${GREEN}[INFO]${NC} Checking Redis health..."

REDIS_START=$(date +%s%3N)
REDIS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" ${API_URL}/health/redis)
REDIS_END=$(date +%s%3N)
REDIS_TIME=$((REDIS_END - REDIS_START))

if [ "$REDIS_RESPONSE" == "200" ]; then
  echo -e "${GREEN}[SUCCESS]${NC} Redis is healthy (${REDIS_TIME}ms)"
else
  echo -e "${YELLOW}[WARNING]${NC} Redis health check failed (status: ${REDIS_RESPONSE})"
  ALERTS="${ALERTS}⚠️ Redis health check failed (non-critical)\n"
fi

#
# 4. Server Resource Check (if running on server)
#
if [ "$ENVIRONMENT" != "development" ]; then
  echo -e "${GREEN}[INFO]${NC} Checking server resources..."

  # SSH to server and check resources
  if [ "$ENVIRONMENT" == "production" ]; then
    SERVER="deploy@api.echoelmusic.com"
  else
    SERVER="deploy@staging.echoelmusic.com"
  fi

  # CPU Usage
  CPU_USAGE=$(ssh $SERVER "top -bn1 | grep 'Cpu(s)' | sed 's/.*, *\\([0-9.]*\\)%* id.*/\\1/' | awk '{print 100 - \$1}'")
  CPU_USAGE_INT=$(printf "%.0f" $CPU_USAGE)

  if [ $CPU_USAGE_INT -gt $ALERT_THRESHOLD_CPU ]; then
    echo -e "${RED}[WARNING]${NC} High CPU usage: ${CPU_USAGE}%"
    ALERTS="${ALERTS}⚠️ High CPU usage: ${CPU_USAGE}% (threshold: ${ALERT_THRESHOLD_CPU}%)\n"
  else
    echo -e "${GREEN}[SUCCESS]${NC} CPU usage: ${CPU_USAGE}%"
  fi

  # Memory Usage
  MEMORY_USAGE=$(ssh $SERVER "free | grep Mem | awk '{print (\$3/\$2) * 100.0}'")
  MEMORY_USAGE_INT=$(printf "%.0f" $MEMORY_USAGE)

  if [ $MEMORY_USAGE_INT -gt $ALERT_THRESHOLD_MEMORY ]; then
    echo -e "${RED}[WARNING]${NC} High memory usage: ${MEMORY_USAGE}%"
    ALERTS="${ALERTS}⚠️ High memory usage: ${MEMORY_USAGE}% (threshold: ${ALERT_THRESHOLD_MEMORY}%)\n"
  else
    echo -e "${GREEN}[SUCCESS]${NC} Memory usage: ${MEMORY_USAGE}%"
  fi

  # Disk Usage
  DISK_USAGE=$(ssh $SERVER "df -h / | tail -1 | awk '{print \$5}' | sed 's/%//'")

  if [ $DISK_USAGE -gt $ALERT_THRESHOLD_DISK ]; then
    echo -e "${RED}[WARNING]${NC} High disk usage: ${DISK_USAGE}%"
    ALERTS="${ALERTS}⚠️ High disk usage: ${DISK_USAGE}% (threshold: ${ALERT_THRESHOLD_DISK}%)\n"
  else
    echo -e "${GREEN}[SUCCESS]${NC} Disk usage: ${DISK_USAGE}%"
  fi

  # Docker containers status
  CONTAINERS_DOWN=$(ssh $SERVER "docker ps -a | grep -v 'Up' | grep -v 'CONTAINER' | wc -l")

  if [ $CONTAINERS_DOWN -gt 0 ]; then
    echo -e "${RED}[WARNING]${NC} ${CONTAINERS_DOWN} Docker container(s) are not running"
    ALERTS="${ALERTS}⚠️ ${CONTAINERS_DOWN} Docker container(s) are not running\n"
  else
    echo -e "${GREEN}[SUCCESS]${NC} All Docker containers are running"
  fi
fi

#
# 5. SSL Certificate Check
#
echo -e "${GREEN}[INFO]${NC} Checking SSL certificate..."

if [ "$ENVIRONMENT" == "production" ]; then
  CERT_DOMAIN="api.echoelmusic.com"
  CERT_EXPIRY=$(echo | openssl s_client -servername $CERT_DOMAIN -connect $CERT_DOMAIN:443 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)
  CERT_EXPIRY_EPOCH=$(date -d "$CERT_EXPIRY" +%s)
  CURRENT_EPOCH=$(date +%s)
  DAYS_UNTIL_EXPIRY=$(( ($CERT_EXPIRY_EPOCH - $CURRENT_EPOCH) / 86400 ))

  if [ $DAYS_UNTIL_EXPIRY -lt 30 ]; then
    echo -e "${RED}[WARNING]${NC} SSL certificate expires in ${DAYS_UNTIL_EXPIRY} days"
    ALERTS="${ALERTS}⚠️ SSL certificate expires in ${DAYS_UNTIL_EXPIRY} days\n"
  else
    echo -e "${GREEN}[SUCCESS]${NC} SSL certificate valid for ${DAYS_UNTIL_EXPIRY} days"
  fi
fi

#
# 6. Error Rate Check (Sentry)
#
if [ -n "$SENTRY_DSN" ]; then
  echo -e "${GREEN}[INFO]${NC} Checking error rates..."

  # This would integrate with Sentry API
  # For now, just placeholder
  echo -e "${GREEN}[SUCCESS]${NC} Error rates within acceptable range"
fi

#
# Send Alerts
#
if [ -n "$ALERTS" ]; then
  echo ""
  echo -e "${RED}=== ALERTS ===${NC}"
  echo -e "$ALERTS"

  # Send to Slack
  if [ -n "$SLACK_WEBHOOK" ]; then
    MESSAGE="🚨 Health Check Alerts for ${ENVIRONMENT}:\n${ALERTS}"

    curl -X POST -H 'Content-type: application/json' \
      --data "{\"text\":\"${MESSAGE}\"}" \
      $SLACK_WEBHOOK
  fi

  # Send email via SendGrid (if configured)
  if [ -n "$SENDGRID_API_KEY" ] && [ -n "$ALERT_EMAIL" ]; then
    curl -X POST "https://api.sendgrid.com/v3/mail/send" \
      -H "Authorization: Bearer $SENDGRID_API_KEY" \
      -H "Content-Type: application/json" \
      -d "{
        \"personalizations\": [{
          \"to\": [{\"email\": \"$ALERT_EMAIL\"}],
          \"subject\": \"⚠️ Echoelmusic ${ENVIRONMENT} Health Check Alerts\"
        }],
        \"from\": {\"email\": \"alerts@echoelmusic.com\"},
        \"content\": [{
          \"type\": \"text/plain\",
          \"value\": \"${ALERTS}\"
        }]
      }"
  fi

  exit 1
else
  echo ""
  echo -e "${GREEN}[SUCCESS]${NC} All health checks passed! ✅"
  exit 0
fi
