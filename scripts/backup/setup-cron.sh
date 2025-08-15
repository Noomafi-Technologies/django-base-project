#!/bin/bash

# Django Base Project - Cron Job Setup Script
# This script sets up automated database backups using cron

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
BACKUP_SCRIPT="$SCRIPT_DIR/backup.sh"

# Function to show usage
show_usage() {
    echo "Usage: $0 [schedule]"
    echo ""
    echo "Schedule options:"
    echo "  daily    - Run backup daily at 2:00 AM (default)"
    echo "  weekly   - Run backup weekly on Sunday at 3:00 AM"
    echo "  hourly   - Run backup every hour"
    echo "  custom   - Enter custom cron schedule"
    echo ""
    echo "Examples:"
    echo "  $0 daily"
    echo "  $0 weekly"
    echo "  $0 custom"
}

# Default schedule
SCHEDULE=${1:-daily}

# Define cron schedules
case $SCHEDULE in
    daily)
        CRON_SCHEDULE="0 2 * * *"
        DESCRIPTION="Daily at 2:00 AM"
        ;;
    weekly)
        CRON_SCHEDULE="0 3 * * 0"
        DESCRIPTION="Weekly on Sunday at 3:00 AM"
        ;;
    hourly)
        CRON_SCHEDULE="0 * * * *"
        DESCRIPTION="Every hour"
        ;;
    custom)
        echo "Enter custom cron schedule (e.g., '0 2 * * *' for daily at 2 AM):"
        read -r CRON_SCHEDULE
        DESCRIPTION="Custom: $CRON_SCHEDULE"
        ;;
    *)
        echo "❌ Error: Invalid schedule option: $SCHEDULE"
        show_usage
        exit 1
        ;;
esac

# Validate cron schedule format
if [[ ! $CRON_SCHEDULE =~ ^[0-9\*\,\-\/\s]+$ ]]; then
    echo "❌ Error: Invalid cron schedule format: $CRON_SCHEDULE"
    exit 1
fi

echo "Setting up automated database backups..."
echo "Schedule: $DESCRIPTION"
echo "Script: $BACKUP_SCRIPT"
echo ""

# Check if backup script exists and is executable
if [ ! -f "$BACKUP_SCRIPT" ]; then
    echo "❌ Error: Backup script not found: $BACKUP_SCRIPT"
    exit 1
fi

# Make backup script executable
chmod +x "$BACKUP_SCRIPT"
echo "✅ Made backup script executable"

# Create cron job entry
CRON_JOB="$CRON_SCHEDULE $BACKUP_SCRIPT >> $PROJECT_ROOT/backups/cron.log 2>&1"

# Check if cron job already exists
if crontab -l 2>/dev/null | grep -q "$BACKUP_SCRIPT"; then
    echo "⚠️ Cron job for backup script already exists"
    echo "Current cron jobs:"
    crontab -l | grep "$BACKUP_SCRIPT"
    echo ""
    read -p "Replace existing cron job? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled"
        exit 0
    fi
    
    # Remove existing cron job
    crontab -l | grep -v "$BACKUP_SCRIPT" | crontab -
    echo "🗑️ Removed existing cron job"
fi

# Add new cron job
(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

# Verify cron job was added
if crontab -l | grep -q "$BACKUP_SCRIPT"; then
    echo "✅ Cron job added successfully!"
    echo ""
    echo "=== CRON JOB DETAILS ==="
    echo "Schedule: $DESCRIPTION"
    echo "Command: $CRON_JOB"
    echo "Log file: $PROJECT_ROOT/backups/cron.log"
    echo "========================"
    echo ""
    echo "You can view all cron jobs with: crontab -l"
    echo "You can remove the cron job with: crontab -e"
else
    echo "❌ Error: Failed to add cron job"
    exit 1
fi

# Create backup directory if it doesn't exist
mkdir -p "$PROJECT_ROOT/backups"

# Create log file with proper permissions
touch "$PROJECT_ROOT/backups/cron.log"
chmod 644 "$PROJECT_ROOT/backups/cron.log"

# Test backup script
echo ""
read -p "Test backup script now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Running test backup..."
    "$BACKUP_SCRIPT"
fi

echo ""
echo "🎉 Automated backup setup completed!"
echo ""
echo "Next steps:"
echo "1. Verify backup script works: $BACKUP_SCRIPT"
echo "2. Check cron logs: tail -f $PROJECT_ROOT/backups/cron.log"
echo "3. Monitor backup files: ls -la $PROJECT_ROOT/backups/"
echo "4. Configure Cloudflare R2 in .env for remote backup storage"