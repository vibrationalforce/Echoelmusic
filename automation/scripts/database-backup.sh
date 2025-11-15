#!/bin/bash
#
# Database Backup Script
# Backs up Supabase PostgreSQL database to S3
#
# Usage: ./database-backup.sh [environment]
# Example: ./database-backup.sh production
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
ENVIRONMENT=${1:-production}
BACKUP_DIR="/tmp/echoelmusic-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="echoelmusic_${ENVIRONMENT}_${TIMESTAMP}.sql"
S3_BUCKET="echoelmusic-backups"

# Load environment variables
if [ -f "../.env.${ENVIRONMENT}" ]; then
  export $(cat "../.env.${ENVIRONMENT}" | grep -v '^#' | xargs)
fi

echo -e "${GREEN}[INFO]${NC} Starting database backup for ${ENVIRONMENT}..."

# Create backup directory
mkdir -p ${BACKUP_DIR}

# Backup database using pg_dump via Supabase
echo -e "${GREEN}[INFO]${NC} Dumping database..."

pg_dump "${SUPABASE_DATABASE_URL}" \
  --format=custom \
  --verbose \
  --file="${BACKUP_DIR}/${BACKUP_FILE}" \
  --exclude-table-data='audit_logs' \
  --exclude-table-data='analytics_events'

if [ $? -eq 0 ]; then
  echo -e "${GREEN}[SUCCESS]${NC} Database dumped successfully"
else
  echo -e "${RED}[ERROR]${NC} Database dump failed"
  exit 1
fi

# Compress backup
echo -e "${GREEN}[INFO]${NC} Compressing backup..."
gzip "${BACKUP_DIR}/${BACKUP_FILE}"
BACKUP_FILE="${BACKUP_FILE}.gz"

# Upload to S3
echo -e "${GREEN}[INFO]${NC} Uploading to S3..."
aws s3 cp "${BACKUP_DIR}/${BACKUP_FILE}" \
  "s3://${S3_BUCKET}/${ENVIRONMENT}/${BACKUP_FILE}" \
  --storage-class STANDARD_IA

if [ $? -eq 0 ]; then
  echo -e "${GREEN}[SUCCESS]${NC} Backup uploaded to S3"
else
  echo -e "${RED}[ERROR]${NC} S3 upload failed"
  exit 1
fi

# Clean up local backup (keep last 3 days)
echo -e "${GREEN}[INFO]${NC} Cleaning up old local backups..."
find ${BACKUP_DIR} -name "echoelmusic_${ENVIRONMENT}_*.sql.gz" -mtime +3 -delete

# Clean up old S3 backups (keep last 30 days)
echo -e "${GREEN}[INFO]${NC} Cleaning up old S3 backups..."
aws s3 ls "s3://${S3_BUCKET}/${ENVIRONMENT}/" | while read -r line; do
  file_date=$(echo $line | awk '{print $1}')
  file_name=$(echo $line | awk '{print $4}')

  # Calculate age in days
  file_timestamp=$(date -d "$file_date" +%s)
  current_timestamp=$(date +%s)
  age_days=$(( (current_timestamp - file_timestamp) / 86400 ))

  # Delete if older than 30 days
  if [ $age_days -gt 30 ]; then
    echo -e "${YELLOW}[INFO]${NC} Deleting old backup: ${file_name}"
    aws s3 rm "s3://${S3_BUCKET}/${ENVIRONMENT}/${file_name}"
  fi
done

# Send notification
if [ -n "$SLACK_WEBHOOK" ]; then
  curl -X POST -H 'Content-type: application/json' \
    --data "{\"text\":\"✅ Database backup completed for ${ENVIRONMENT}: ${BACKUP_FILE}\"}" \
    $SLACK_WEBHOOK
fi

echo -e "${GREEN}[SUCCESS]${NC} Backup process completed!"
echo -e "${GREEN}[INFO]${NC} Backup file: ${BACKUP_FILE}"
echo -e "${GREEN}[INFO]${NC} S3 location: s3://${S3_BUCKET}/${ENVIRONMENT}/${BACKUP_FILE}"

# Remove local backup file
rm -f "${BACKUP_DIR}/${BACKUP_FILE}"

exit 0
