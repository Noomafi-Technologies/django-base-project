import os
import subprocess
from datetime import datetime, timedelta
from django.conf import settings
from django.core.management import call_command
from django.core.mail import send_mail
from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken, OutstandingToken
from celery import shared_task
import logging

logger = logging.getLogger(__name__)


@shared_task
def cleanup_expired_tokens():
    """Clean up expired JWT tokens from the database."""
    try:
        cutoff_date = datetime.now() - timedelta(days=7)
        
        # Clean up blacklisted tokens older than 7 days
        deleted_blacklisted = BlacklistedToken.objects.filter(
            blacklisted_at__lt=cutoff_date
        ).delete()
        
        # Clean up outstanding tokens that are expired
        deleted_outstanding = OutstandingToken.objects.filter(
            expires_at__lt=datetime.now()
        ).delete()
        
        logger.info(f"Cleaned up {deleted_blacklisted[0]} blacklisted tokens and {deleted_outstanding[0]} outstanding tokens")
        return f"Cleaned up {deleted_blacklisted[0]} blacklisted and {deleted_outstanding[0]} outstanding tokens"
    
    except Exception as e:
        logger.error(f"Error cleaning up tokens: {str(e)}")
        return f"Error: {str(e)}"


@shared_task
def database_backup():
    """Create a database backup."""
    try:
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        backup_filename = f"backup_{timestamp}.sql"
        backup_path = os.path.join(settings.BASE_DIR, 'backups', backup_filename)
        
        # Ensure backup directory exists
        os.makedirs(os.path.dirname(backup_path), exist_ok=True)
        
        # Get database settings
        db_settings = settings.DATABASES['default']
        
        if db_settings['ENGINE'] == 'django.db.backends.postgresql':
            # PostgreSQL backup
            cmd = [
                'pg_dump',
                f"--host={db_settings['HOST']}",
                f"--port={db_settings['PORT']}",
                f"--username={db_settings['USER']}",
                f"--dbname={db_settings['NAME']}",
                '--no-password',
                '--verbose',
                '--file', backup_path
            ]
            
            env = os.environ.copy()
            env['PGPASSWORD'] = db_settings['PASSWORD']
            
            result = subprocess.run(cmd, env=env, capture_output=True, text=True)
            
            if result.returncode == 0:
                logger.info(f"Database backup created successfully: {backup_path}")
                
                # Upload to Cloudflare R2 if configured
                if hasattr(settings, 'USE_CLOUDFLARE_R2') and settings.USE_CLOUDFLARE_R2:
                    upload_backup_to_r2(backup_path, backup_filename)
                
                return f"Backup created: {backup_filename}"
            else:
                logger.error(f"Database backup failed: {result.stderr}")
                return f"Backup failed: {result.stderr}"
        
        else:
            # SQLite backup (for development)
            import shutil
            db_path = db_settings['NAME']
            shutil.copy2(db_path, backup_path)
            logger.info(f"SQLite backup created: {backup_path}")
            return f"SQLite backup created: {backup_filename}"
    
    except Exception as e:
        logger.error(f"Database backup error: {str(e)}")
        return f"Backup error: {str(e)}"


def upload_backup_to_r2(local_path, filename):
    """Upload backup file to Cloudflare R2."""
    try:
        import boto3
        from botocore.exceptions import ClientError
        
        # Cloudflare R2 uses S3-compatible API
        r2_client = boto3.client(
            's3',
            endpoint_url=settings.AWS_S3_ENDPOINT_URL,
            aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
            region_name=settings.AWS_S3_REGION_NAME
        )
        
        r2_key = f"backups/{filename}"
        r2_client.upload_file(local_path, settings.AWS_STORAGE_BUCKET_NAME, r2_key)
        
        logger.info(f"Backup uploaded to Cloudflare R2: {settings.AWS_STORAGE_BUCKET_NAME}/{r2_key}")
        
        # Remove local file after successful upload
        os.remove(local_path)
        
    except Exception as e:
        logger.error(f"Failed to upload backup to Cloudflare R2: {str(e)}")


@shared_task
def weekly_backup():
    """Perform weekly backup and cleanup."""
    try:
        # Create backup
        backup_result = database_backup()
        
        # Clean up old backups (keep last 4 weeks)
        cleanup_old_backups()
        
        # Send notification email
        send_backup_notification(backup_result)
        
        return f"Weekly backup completed: {backup_result}"
    
    except Exception as e:
        logger.error(f"Weekly backup error: {str(e)}")
        return f"Weekly backup error: {str(e)}"


def cleanup_old_backups():
    """Remove backup files older than 4 weeks."""
    try:
        backup_dir = os.path.join(settings.BASE_DIR, 'backups')
        if not os.path.exists(backup_dir):
            return
        
        cutoff_date = datetime.now() - timedelta(weeks=4)
        
        for filename in os.listdir(backup_dir):
            file_path = os.path.join(backup_dir, filename)
            if os.path.isfile(file_path):
                file_time = datetime.fromtimestamp(os.path.getctime(file_path))
                if file_time < cutoff_date:
                    os.remove(file_path)
                    logger.info(f"Removed old backup: {filename}")
    
    except Exception as e:
        logger.error(f"Error cleaning up old backups: {str(e)}")


def send_backup_notification(result):
    """Send email notification about backup status."""
    try:
        subject = "Database Backup Notification"
        message = f"Database backup completed.\n\nResult: {result}\n\nTimestamp: {datetime.now()}"
        
        # Get admin emails
        admin_emails = [email for name, email in settings.ADMINS] if hasattr(settings, 'ADMINS') else []
        
        if admin_emails:
            send_mail(
                subject=subject,
                message=message,
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=admin_emails,
                fail_silently=False
            )
            logger.info("Backup notification email sent")
    
    except Exception as e:
        logger.error(f"Failed to send backup notification: {str(e)}")


@shared_task
def health_check_monitoring():
    """Perform application health checks and send alerts if needed."""
    try:
        from django.core.management import call_command
        from io import StringIO
        
        # Capture health check output
        output = StringIO()
        call_command('health_check', stdout=output)
        health_status = output.getvalue()
        
        # Check if any services are failing
        if 'ERROR' in health_status or 'FAIL' in health_status:
            # Send alert email
            subject = "Application Health Check Alert"
            message = f"Health check detected issues:\n\n{health_status}"
            
            admin_emails = [email for name, email in settings.ADMINS] if hasattr(settings, 'ADMINS') else []
            
            if admin_emails:
                send_mail(
                    subject=subject,
                    message=message,
                    from_email=settings.DEFAULT_FROM_EMAIL,
                    recipient_list=admin_emails,
                    fail_silently=False
                )
            
            logger.warning(f"Health check issues detected: {health_status}")
            return f"Health check issues detected: {health_status}"
        
        logger.info("Health check passed")
        return "Health check passed"
    
    except Exception as e:
        logger.error(f"Health check monitoring error: {str(e)}")
        return f"Health check error: {str(e)}"