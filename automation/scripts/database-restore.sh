#!/bin/bash
#
# Database Restore Script
# Restores Supabase PostgreSQL database from S3 backup
#
# Usage: ./database-restore.sh [environment] [backup_file]
# Example: ./database-restore.sh production echoelmusic_production_20250115_120000.sql.gz
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
ENVIRONMENT=${1:-production}
BACKUP_FILE=${2}
BACKUP_DIR="/tmp/echoelmusic-restores"
S3_BUCKET="echoelmusic-backups"

# Validate arguments
if [ -z "$BACKUP_FILE" ]; then
  echo -e "${RED}[ERROR]${NC} Backup file not specified"
  echo "Usage: ./database-restore.sh [environment] [backup_file]"
  exit 1
fi

# Load environment variables
if [ -f "../.env.${ENVIRONMENT}" ]; then
  export $(cat "../.env.${ENVIRONMENT}" | grep -v '^#' | xargs)
fi

# Safety check for production
if [ "$ENVIRONMENT" == "production" ]; then
  echo -e "${RED}[WARNING]${NC} You are about to restore the PRODUCTION database!"
  echo -e "${RED}[WARNING]${NC} This will OVERWRITE all current data!"
  read -p "$(echo -e ${YELLOW}Are you ABSOLUTELY sure? Type 'RESTORE PRODUCTION' to confirm: ${NC})" -r
  echo

  if [[ ! $REPLY == "RESTORE PRODUCTION" ]]; then
    echo -e "${YELLOW}[INFO]${NC} Restore cancelled"
    exit 0
  fi
fi

echo -e "${GREEN}[INFO]${NC} Starting database restore for ${ENVIRONMENT}..."

# Create restore directory
mkdir -p ${BACKUP_DIR}

# Download from S3
echo -e "${GREEN}[INFO]${NC} Downloading backup from S3..."
aws s3 cp "s3://${S3_BUCKET}/${ENVIRONMENT}/${BACKUP_FILE}" \
  "${BACKUP_DIR}/${BACKUP_FILE}"

if [ $? -ne 0 ]; then
  echo -e "${RED}[ERROR]${NC} Failed to download backup from S3"
  exit 1
fi

# Decompress backup
echo -e "${GREEN}[INFO]${NC} Decompressing backup..."
gunzip "${BACKUP_DIR}/${BACKUP_FILE}"
BACKUP_FILE="${BACKUP_FILE%.gz}"

# Create pre-restore backup
echo -e "${GREEN}[INFO]${NC} Creating pre-restore backup..."
PRE_RESTORE_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PRE_RESTORE_FILE="pre_restore_${ENVIRONMENT}_${PRE_RESTORE_TIMESTAMP}.sql"

pg_dump "${SUPABASE_DATABASE_URL}" \
  --format=custom \
  --file="${BACKUP_DIR}/${PRE_RESTORE_FILE}"

gzip "${BACKUP_DIR}/${PRE_RESTORE_FILE}"

aws s3 cp "${BACKUP_DIR}/${PRE_RESTORE_FILE}.gz" \
  "s3://${S3_BUCKET}/${ENVIRONMENT}/pre-restore/${PRE_RESTORE_FILE}.gz"

echo -e "${GREEN}[SUCCESS]${NC} Pre-restore backup created: ${PRE_RESTORE_FILE}.gz"

# Drop existing connections
echo -e "${GREEN}[INFO]${NC} Dropping existing database connections..."
psql "${SUPABASE_DATABASE_URL}" -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = current_database() AND pid <> pg_backend_pid();"

# Restore database
echo -e "${GREEN}[INFO]${NC} Restoring database..."
pg_restore --clean --if-exists \
  --verbose \
  --dbname="${SUPABASE_DATABASE_URL}" \
  "${BACKUP_DIR}/${BACKUP_FILE}"

if [ $? -eq 0 ]; then
  echo -e "${GREEN}[SUCCESS]${NC} Database restored successfully"
else
  echo -e "${RED}[ERROR]${NC} Database restore failed"
  echo -e "${YELLOW}[INFO]${NC} You can restore the pre-restore backup if needed:"
  echo -e "${YELLOW}[INFO]${NC} ./database-restore.sh ${ENVIRONMENT} pre-restore/${PRE_RESTORE_FILE}.gz"
  exit 1
fi

# Run migrations to ensure schema is up to date
echo -e "${GREEN}[INFO]${NC} Running migrations..."
cd ../backend
npm run migrate

# Vacuum and analyze database
echo -e "${GREEN}[INFO]${NC} Optimizing database..."
psql "${SUPABASE_DATABASE_URL}" -c "VACUUM ANALYZE;"

# Clean up
echo -e "${GREEN}[INFO]${NC} Cleaning up..."
rm -f "${BACKUP_DIR}/${BACKUP_FILE}"
rm -f "${BACKUP_DIR}/${PRE_RESTORE_FILE}.gz"

# Send notification
if [ -n "$SLACK_WEBHOOK" ]; then
  curl -X POST -H 'Content-type: application/json' \
    --data "{\"text\":\"✅ Database restored for ${ENVIRONMENT} from ${BACKUP_FILE}\"}" \
    $SLACK_WEBHOOK
fi

echo -e "${GREEN}[SUCCESS]${NC} Restore process completed!"
echo -e "${GREEN}[INFO]${NC} Restored from: ${BACKUP_FILE}"
echo -e "${GREEN}[INFO]${NC} Pre-restore backup: s3://${S3_BUCKET}/${ENVIRONMENT}/pre-restore/${PRE_RESTORE_FILE}.gz"

exit 0
