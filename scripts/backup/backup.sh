#!/bin/bash

# Django Base Project - Database Backup Script
# This script creates backups of the PostgreSQL database and uploads to Cloudflare R2

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
BACKUP_DIR="$PROJECT_ROOT/backups"
LOG_FILE="$BACKUP_DIR/backup.log"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILENAME="django_base_backup_${DATE}.sql"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_FILENAME"

# Load environment variables
if [ -f "$PROJECT_ROOT/.env" ]; then
    export $(grep -v '^#' "$PROJECT_ROOT/.env" | xargs)
fi

# Default values
DB_NAME=${DB_NAME:-django_base_prod}
DB_USER=${DB_USER:-django_user}
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-5432}
BACKUP_RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-30}

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

log "Starting database backup..."
log "Database: $DB_NAME"
log "Backup file: $BACKUP_FILENAME"

# Check if running in Docker environment
if [ -f /.dockerenv ] || grep -q docker /proc/1/cgroup 2>/dev/null; then
    log "Running in Docker environment"
    DOCKER_CMD="docker-compose -f $PROJECT_ROOT/docker-compose.prod.yml exec -T db"
else
    log "Running in host environment"
    DOCKER_CMD=""
fi

# Create database backup
log "Creating database backup..."
if [ -n "$DOCKER_CMD" ]; then
    # Docker environment
    $DOCKER_CMD pg_dump -U "$DB_USER" -h localhost -p 5432 "$DB_NAME" > "$BACKUP_PATH"
else
    # Host environment
    export PGPASSWORD="$DB_PASSWORD"
    pg_dump -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" "$DB_NAME" > "$BACKUP_PATH"
fi

# Check if backup was successful
if [ $? -eq 0 ] && [ -s "$BACKUP_PATH" ]; then
    BACKUP_SIZE=$(du -h "$BACKUP_PATH" | cut -f1)
    log "✅ Database backup created successfully: $BACKUP_FILENAME ($BACKUP_SIZE)"
else
    log "❌ Database backup failed!"
    exit 1
fi

# Compress backup
log "Compressing backup..."
gzip "$BACKUP_PATH"
COMPRESSED_BACKUP="$BACKUP_PATH.gz"

if [ -f "$COMPRESSED_BACKUP" ]; then
    COMPRESSED_SIZE=$(du -h "$COMPRESSED_BACKUP" | cut -f1)
    log "✅ Backup compressed: $BACKUP_FILENAME.gz ($COMPRESSED_SIZE)"
else
    log "❌ Backup compression failed!"
    exit 1
fi

# Upload to Cloudflare R2 if configured
if [ "$USE_CLOUDFLARE_R2" = "true" ] && [ -n "$CLOUDFLARE_R2_BUCKET_NAME" ]; then
    log "Uploading backup to Cloudflare R2..."
    
    # Use AWS CLI with R2 endpoint
    aws s3 cp "$COMPRESSED_BACKUP" \
        "s3://$CLOUDFLARE_R2_BUCKET_NAME/backups/$(basename "$COMPRESSED_BACKUP")" \
        --endpoint-url "$CLOUDFLARE_R2_ENDPOINT_URL" \
        --region auto
    
    if [ $? -eq 0 ]; then
        log "✅ Backup uploaded to Cloudflare R2"
        # Remove local compressed backup after successful upload
        rm "$COMPRESSED_BACKUP"
        log "🗑️ Local compressed backup removed"
    else
        log "❌ Failed to upload backup to Cloudflare R2"
    fi
else
    log "ℹ️ Cloudflare R2 upload skipped (not configured or disabled)"
fi

# Clean up old backups
log "Cleaning up old backups (older than $BACKUP_RETENTION_DAYS days)..."
find "$BACKUP_DIR" -name "django_base_backup_*.sql.gz" -type f -mtime +$BACKUP_RETENTION_DAYS -delete
CLEANED_COUNT=$(find "$BACKUP_DIR" -name "django_base_backup_*.sql.gz" -type f -mtime +$BACKUP_RETENTION_DAYS | wc -l)
log "🗑️ Cleaned up $CLEANED_COUNT old backup files"

# Send notification email if configured
if [ -n "$BACKUP_NOTIFICATION_EMAIL" ] && command -v mail >/dev/null 2>&1; then
    log "Sending backup notification email..."
    echo "Database backup completed successfully.

Backup Details:
- Date: $(date)
- Database: $DB_NAME
- Backup File: $BACKUP_FILENAME.gz
- Size: $COMPRESSED_SIZE
- Location: Cloudflare R2 (if configured)

This is an automated message from your Django Base Project backup system." | \
    mail -s "✅ Database Backup Successful - $(date +%Y-%m-%d)" "$BACKUP_NOTIFICATION_EMAIL"
fi

log "✅ Backup process completed successfully!"

# Output summary
echo ""
echo "=== BACKUP SUMMARY ==="
echo "Date: $(date)"
echo "Database: $DB_NAME"
echo "Backup File: $BACKUP_FILENAME.gz"
echo "Size: $COMPRESSED_SIZE"
echo "Status: ✅ Success"
echo "======================="