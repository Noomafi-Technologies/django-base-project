#!/bin/bash

# Django Base Project - Database Restore Script
# This script restores a PostgreSQL database from a backup file

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
BACKUP_DIR="$PROJECT_ROOT/backups"
LOG_FILE="$BACKUP_DIR/restore.log"

# Load environment variables
if [ -f "$PROJECT_ROOT/.env" ]; then
    export $(grep -v '^#' "$PROJECT_ROOT/.env" | xargs)
fi

# Default values
DB_NAME=${DB_NAME:-django_base_prod}
DB_USER=${DB_USER:-django_user}
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-5432}

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 <backup_file>"
    echo ""
    echo "Examples:"
    echo "  $0 django_base_backup_20241215_143022.sql.gz"
    echo "  $0 /path/to/backup.sql"
    echo ""
    echo "Available backups in $BACKUP_DIR:"
    if [ -d "$BACKUP_DIR" ]; then
        ls -la "$BACKUP_DIR"/*.sql* 2>/dev/null || echo "  No backup files found"
    else
        echo "  Backup directory not found"
    fi
}

# Check if backup file argument is provided
if [ $# -eq 0 ]; then
    echo "❌ Error: No backup file specified"
    show_usage
    exit 1
fi

BACKUP_FILE="$1"

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    # Try looking in the backup directory
    if [ -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
        BACKUP_FILE="$BACKUP_DIR/$BACKUP_FILE"
    else
        echo "❌ Error: Backup file not found: $BACKUP_FILE"
        show_usage
        exit 1
    fi
fi

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

log "Starting database restore..."
log "Backup file: $BACKUP_FILE"
log "Database: $DB_NAME"

# Check if file is compressed
if [[ "$BACKUP_FILE" == *.gz ]]; then
    log "Backup file is compressed, decompressing..."
    TEMP_FILE="${BACKUP_FILE%.gz}"
    gunzip -c "$BACKUP_FILE" > "$TEMP_FILE"
    RESTORE_FILE="$TEMP_FILE"
    CLEANUP_TEMP=true
else
    RESTORE_FILE="$BACKUP_FILE"
    CLEANUP_TEMP=false
fi

# Verify SQL file
if ! head -n 5 "$RESTORE_FILE" | grep -q "PostgreSQL"; then
    log "⚠️ Warning: File doesn't appear to be a PostgreSQL dump"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Restore cancelled by user"
        exit 1
    fi
fi

# Warning before restore
echo "⚠️  WARNING: This will OVERWRITE the current database!"
echo "Database: $DB_NAME"
echo "Backup file: $BACKUP_FILE"
echo ""
read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Restore cancelled by user"
    exit 1
fi

# Check if running in Docker environment
if [ -f /.dockerenv ] || grep -q docker /proc/1/cgroup 2>/dev/null; then
    log "Running in Docker environment"
    DOCKER_CMD="docker-compose -f $PROJECT_ROOT/docker-compose.prod.yml exec -T db"
else
    log "Running in host environment"
    DOCKER_CMD=""
fi

# Stop application services during restore
log "Stopping application services..."
if [ -n "$DOCKER_CMD" ]; then
    docker-compose -f "$PROJECT_ROOT/docker-compose.prod.yml" stop web celery celery-beat
fi

# Create a backup of current database before restore
CURRENT_BACKUP="$BACKUP_DIR/pre_restore_backup_$(date +%Y%m%d_%H%M%S).sql"
log "Creating backup of current database before restore..."

if [ -n "$DOCKER_CMD" ]; then
    # Docker environment
    $DOCKER_CMD pg_dump -U "$DB_USER" -h localhost -p 5432 "$DB_NAME" > "$CURRENT_BACKUP"
else
    # Host environment
    export PGPASSWORD="$DB_PASSWORD"
    pg_dump -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" "$DB_NAME" > "$CURRENT_BACKUP"
fi

if [ $? -eq 0 ]; then
    log "✅ Current database backed up to: $(basename "$CURRENT_BACKUP")"
else
    log "❌ Failed to backup current database"
    read -p "Continue with restore anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Restore cancelled"
        exit 1
    fi
fi

# Drop and recreate database
log "Dropping and recreating database..."
if [ -n "$DOCKER_CMD" ]; then
    # Docker environment
    $DOCKER_CMD psql -U "$DB_USER" -h localhost -p 5432 -c "DROP DATABASE IF EXISTS $DB_NAME;"
    $DOCKER_CMD psql -U "$DB_USER" -h localhost -p 5432 -c "CREATE DATABASE $DB_NAME;"
else
    # Host environment
    export PGPASSWORD="$DB_PASSWORD"
    psql -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -c "DROP DATABASE IF EXISTS $DB_NAME;"
    psql -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -c "CREATE DATABASE $DB_NAME;"
fi

# Restore database
log "Restoring database from backup..."
if [ -n "$DOCKER_CMD" ]; then
    # Docker environment
    $DOCKER_CMD psql -U "$DB_USER" -h localhost -p 5432 "$DB_NAME" < "$RESTORE_FILE"
else
    # Host environment
    export PGPASSWORD="$DB_PASSWORD"
    psql -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" "$DB_NAME" < "$RESTORE_FILE"
fi

if [ $? -eq 0 ]; then
    log "✅ Database restored successfully!"
else
    log "❌ Database restore failed!"
    
    # Attempt to restore from the backup we just created
    log "Attempting to restore from pre-restore backup..."
    if [ -f "$CURRENT_BACKUP" ]; then
        if [ -n "$DOCKER_CMD" ]; then
            $DOCKER_CMD psql -U "$DB_USER" -h localhost -p 5432 "$DB_NAME" < "$CURRENT_BACKUP"
        else
            psql -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" "$DB_NAME" < "$CURRENT_BACKUP"
        fi
        log "Database restored from pre-restore backup"
    fi
    exit 1
fi

# Clean up temporary file
if [ "$CLEANUP_TEMP" = true ] && [ -f "$TEMP_FILE" ]; then
    rm "$TEMP_FILE"
    log "🗑️ Temporary decompressed file removed"
fi

# Restart application services
log "Restarting application services..."
if [ -n "$DOCKER_CMD" ]; then
    docker-compose -f "$PROJECT_ROOT/docker-compose.prod.yml" start web celery celery-beat
fi

# Run migrations to ensure database is up to date
log "Running Django migrations..."
if [ -n "$DOCKER_CMD" ]; then
    docker-compose -f "$PROJECT_ROOT/docker-compose.prod.yml" exec web python manage.py migrate
else
    cd "$PROJECT_ROOT" && python manage.py migrate
fi

log "✅ Database restore completed successfully!"

# Output summary
echo ""
echo "=== RESTORE SUMMARY ==="
echo "Date: $(date)"
echo "Database: $DB_NAME"
echo "Restored from: $(basename "$BACKUP_FILE")"
echo "Pre-restore backup: $(basename "$CURRENT_BACKUP")"
echo "Status: ✅ Success"
echo "======================="