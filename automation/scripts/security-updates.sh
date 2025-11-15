#!/bin/bash
#
# Security Updates Script
# Checks for and applies security updates to dependencies
#
# Usage: ./security-updates.sh [environment]
# Example: ./security-updates.sh production
#
# Run weekly via cron: 0 3 * * 1 /path/to/security-updates.sh production
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
ENVIRONMENT=${1:-staging}
AUTO_APPLY=${2:-false}  # Set to 'true' to auto-apply updates

echo -e "${BLUE}[INFO]${NC} Checking for security updates (${ENVIRONMENT})..."

#
# 1. Backend Dependencies (npm)
#
echo ""
echo -e "${GREEN}=== Backend Dependencies (npm) ===${NC}"
cd ../backend

# Check for vulnerabilities
echo -e "${BLUE}[INFO]${NC} Running npm audit..."
NPM_AUDIT_OUTPUT=$(npm audit --json)
NPM_VULNERABILITIES=$(echo $NPM_AUDIT_OUTPUT | jq '.metadata.vulnerabilities')

CRITICAL=$(echo $NPM_VULNERABILITIES | jq '.critical')
HIGH=$(echo $NPM_VULNERABILITIES | jq '.high')
MODERATE=$(echo $NPM_VULNERABILITIES | jq '.moderate')
LOW=$(echo $NPM_VULNERABILITIES | jq '.low')

echo -e "${BLUE}[INFO]${NC} Found vulnerabilities:"
echo "  Critical: $CRITICAL"
echo "  High:     $HIGH"
echo "  Moderate: $MODERATE"
echo "  Low:      $LOW"

# Alert if critical or high vulnerabilities
if [ $CRITICAL -gt 0 ] || [ $HIGH -gt 0 ]; then
  echo -e "${RED}[WARNING]${NC} Critical or high vulnerabilities found!"

  # Auto-fix if enabled
  if [ "$AUTO_APPLY" == "true" ]; then
    echo -e "${YELLOW}[INFO]${NC} Auto-applying security fixes..."
    npm audit fix --force

    # Run tests to ensure fixes didn't break anything
    echo -e "${BLUE}[INFO]${NC} Running tests..."
    npm test

    if [ $? -eq 0 ]; then
      echo -e "${GREEN}[SUCCESS]${NC} Security fixes applied and tests passed"

      # Commit changes
      git add package.json package-lock.json
      git commit -m "security: Apply npm security updates"

      # Deploy to staging first
      if [ "$ENVIRONMENT" == "production" ]; then
        echo -e "${YELLOW}[INFO]${NC} Deploying to staging for testing..."
        ../automation/deploy.sh staging $(git describe --tags --abbrev=0)
      else
        echo -e "${YELLOW}[INFO]${NC} Deploying to ${ENVIRONMENT}..."
        ../automation/deploy.sh $ENVIRONMENT $(git describe --tags --abbrev=0)
      fi
    else
      echo -e "${RED}[ERROR]${NC} Tests failed after applying security fixes"
      git checkout package.json package-lock.json
      exit 1
    fi
  else
    echo -e "${YELLOW}[INFO]${NC} Run with 'true' as second argument to auto-apply fixes"
  fi
fi

#
# 2. Docker Base Images
#
echo ""
echo -e "${GREEN}=== Docker Base Images ===${NC}"

# Check for updates to base images
echo -e "${BLUE}[INFO]${NC} Checking Docker base images..."

DOCKERFILE="../backend/Dockerfile"
BASE_IMAGE=$(grep "^FROM" $DOCKERFILE | head -1 | awk '{print $2}')

echo -e "${BLUE}[INFO]${NC} Current base image: $BASE_IMAGE"

# Pull latest version
docker pull $BASE_IMAGE

# Check if there's a newer version
CURRENT_DIGEST=$(docker images --digests --format "{{.Digest}}" $BASE_IMAGE | head -1)
LATEST_DIGEST=$(docker images --digests --format "{{.Digest}}" $BASE_IMAGE | tail -1)

if [ "$CURRENT_DIGEST" != "$LATEST_DIGEST" ]; then
  echo -e "${YELLOW}[INFO]${NC} Newer base image available"

  if [ "$AUTO_APPLY" == "true" ]; then
    echo -e "${YELLOW}[INFO]${NC} Rebuilding Docker images..."

    # Rebuild images
    cd ../backend
    docker build -t echoelmusic/backend:latest .

    # Test the new image
    echo -e "${BLUE}[INFO]${NC} Testing new image..."
    docker run --rm echoelmusic/backend:latest npm test

    if [ $? -eq 0 ]; then
      echo -e "${GREEN}[SUCCESS]${NC} New image tests passed"

      # Push to registry
      docker push echoelmusic/backend:latest

      # Deploy
      if [ "$ENVIRONMENT" == "production" ]; then
        echo -e "${YELLOW}[INFO]${NC} Deploying to staging first..."
        ../automation/deploy.sh staging $(git describe --tags --abbrev=0)
      else
        ../automation/deploy.sh $ENVIRONMENT $(git describe --tags --abbrev=0)
      fi
    else
      echo -e "${RED}[ERROR]${NC} Tests failed with new base image"
      exit 1
    fi
  fi
else
  echo -e "${GREEN}[SUCCESS]${NC} Base image is up to date"
fi

#
# 3. System Packages (on server)
#
echo ""
echo -e "${GREEN}=== System Packages ===${NC}"

if [ "$ENVIRONMENT" != "development" ]; then
  if [ "$ENVIRONMENT" == "production" ]; then
    SERVER="deploy@api.echoelmusic.com"
  else
    SERVER="deploy@staging.echoelmusic.com"
  fi

  echo -e "${BLUE}[INFO]${NC} Checking system updates on $SERVER..."

  # Check for updates
  UPDATES=$(ssh $SERVER "apt-get update > /dev/null 2>&1 && apt-get -s upgrade | grep -P '^\d+ upgraded' || echo '0 upgraded'")
  UPDATE_COUNT=$(echo $UPDATES | awk '{print $1}')

  echo -e "${BLUE}[INFO]${NC} Available system updates: $UPDATE_COUNT"

  # Check for security updates specifically
  SECURITY_UPDATES=$(ssh $SERVER "apt-get upgrade -s 2>/dev/null | grep -i security | wc -l")

  echo -e "${BLUE}[INFO]${NC} Available security updates: $SECURITY_UPDATES"

  if [ $SECURITY_UPDATES -gt 0 ]; then
    echo -e "${YELLOW}[WARNING]${NC} Security updates available"

    if [ "$AUTO_APPLY" == "true" ]; then
      echo -e "${YELLOW}[INFO]${NC} Applying security updates..."

      ssh $SERVER "sudo apt-get update && sudo apt-get upgrade -y --only-upgrade"

      # Restart services if needed
      if [ -f /var/run/reboot-required ]; then
        echo -e "${RED}[WARNING]${NC} Reboot required on server!"

        # Send notification
        if [ -n "$SLACK_WEBHOOK" ]; then
          curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"⚠️ Server reboot required for ${ENVIRONMENT} after security updates\"}" \
            $SLACK_WEBHOOK
        fi
      else
        # Just restart services
        ssh $SERVER "cd /opt/echoelmusic && docker-compose restart"
      fi

      echo -e "${GREEN}[SUCCESS]${NC} Security updates applied"
    fi
  else
    echo -e "${GREEN}[SUCCESS]${NC} No security updates needed"
  fi
fi

#
# 4. GitHub Security Advisories
#
echo ""
echo -e "${GREEN}=== GitHub Security Advisories ===${NC}"

cd ..

# Check for Dependabot alerts (requires GitHub CLI)
if command -v gh &> /dev/null; then
  echo -e "${BLUE}[INFO]${NC} Checking GitHub security advisories..."

  ADVISORIES=$(gh api repos/:owner/:repo/vulnerability-alerts 2>/dev/null | jq length)

  if [ $? -eq 0 ] && [ $ADVISORIES -gt 0 ]; then
    echo -e "${YELLOW}[WARNING]${NC} $ADVISORIES security advisories found"
    echo -e "${BLUE}[INFO]${NC} View them at: https://github.com/vibrationalforce/Echoelmusic/security/dependabot"
  else
    echo -e "${GREEN}[SUCCESS]${NC} No security advisories"
  fi
else
  echo -e "${YELLOW}[INFO]${NC} GitHub CLI not installed, skipping advisory check"
fi

#
# 5. SSL Certificate Renewal
#
echo ""
echo -e "${GREEN}=== SSL Certificate ===${NC}"

if [ "$ENVIRONMENT" == "production" ]; then
  CERT_DOMAIN="api.echoelmusic.com"

  echo -e "${BLUE}[INFO]${NC} Checking SSL certificate for $CERT_DOMAIN..."

  CERT_EXPIRY=$(echo | openssl s_client -servername $CERT_DOMAIN -connect $CERT_DOMAIN:443 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)
  CERT_EXPIRY_EPOCH=$(date -d "$CERT_EXPIRY" +%s)
  CURRENT_EPOCH=$(date +%s)
  DAYS_UNTIL_EXPIRY=$(( ($CERT_EXPIRY_EPOCH - $CURRENT_EPOCH) / 86400 ))

  echo -e "${BLUE}[INFO]${NC} Certificate expires in $DAYS_UNTIL_EXPIRY days"

  if [ $DAYS_UNTIL_EXPIRY -lt 30 ]; then
    echo -e "${YELLOW}[WARNING]${NC} Certificate expiring soon!"

    if [ "$AUTO_APPLY" == "true" ]; then
      echo -e "${YELLOW}[INFO]${NC} Renewing certificate..."

      # Renew Let's Encrypt certificate
      ssh $SERVER "sudo certbot renew --nginx"

      echo -e "${GREEN}[SUCCESS]${NC} Certificate renewed"
    fi
  else
    echo -e "${GREEN}[SUCCESS]${NC} Certificate is valid"
  fi
fi

#
# Generate Report
#
echo ""
echo -e "${GREEN}=== Security Update Report ===${NC}"
echo ""
echo "Environment: $ENVIRONMENT"
echo "Date: $(date)"
echo ""
echo "NPM Vulnerabilities:"
echo "  Critical: $CRITICAL"
echo "  High:     $HIGH"
echo "  Moderate: $MODERATE"
echo "  Low:      $LOW"
echo ""
echo "System Updates: $UPDATE_COUNT available"
echo "Security Updates: $SECURITY_UPDATES available"
echo ""

# Send summary to Slack
if [ -n "$SLACK_WEBHOOK" ]; then
  MESSAGE="📊 Security Update Report - ${ENVIRONMENT}\n\n"
  MESSAGE="${MESSAGE}NPM Vulnerabilities:\n"
  MESSAGE="${MESSAGE}  Critical: $CRITICAL\n"
  MESSAGE="${MESSAGE}  High: $HIGH\n"
  MESSAGE="${MESSAGE}  Moderate: $MODERATE\n\n"
  MESSAGE="${MESSAGE}System Updates: $UPDATE_COUNT available\n"
  MESSAGE="${MESSAGE}Security Updates: $SECURITY_UPDATES available"

  curl -X POST -H 'Content-type: application/json' \
    --data "{\"text\":\"${MESSAGE}\"}" \
    $SLACK_WEBHOOK
fi

echo -e "${GREEN}[SUCCESS]${NC} Security update check complete!"

exit 0
