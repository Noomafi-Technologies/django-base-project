import secrets
import string
from django.db import models
from django.conf import settings
from django.utils import timezone
from .mixins import TimestampMixin


class APIKey(TimestampMixin):
    """Model for API key authentication."""
    
    name = models.CharField(max_length=100, help_text="Human-readable name for this API key")
    key = models.CharField(max_length=64, unique=True, db_index=True)
    prefix = models.CharField(max_length=8, help_text="First 8 characters of the key for identification")
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='api_keys'
    )
    is_active = models.BooleanField(default=True)
    last_used = models.DateTimeField(null=True, blank=True)
    expires_at = models.DateTimeField(null=True, blank=True, help_text="Optional expiration date")
    
    # Permissions and scopes
    can_read = models.BooleanField(default=True)
    can_write = models.BooleanField(default=False)
    can_delete = models.BooleanField(default=False)
    allowed_ips = models.TextField(
        blank=True,
        help_text="Comma-separated list of allowed IP addresses. Leave blank for no restriction."
    )
    
    # Usage tracking
    request_count = models.PositiveIntegerField(default=0)
    max_requests_per_hour = models.PositiveIntegerField(
        null=True,
        blank=True,
        help_text="Maximum requests per hour. Leave blank for no limit."
    )

    class Meta:
        db_table = 'api_keys'
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.name} ({self.prefix}...)"

    def save(self, *args, **kwargs):
        if not self.key:
            self.key = self.generate_key()
            self.prefix = self.key[:8]
        super().save(*args, **kwargs)

    @staticmethod
    def generate_key():
        """Generate a secure API key."""
        alphabet = string.ascii_letters + string.digits
        return ''.join(secrets.choice(alphabet) for _ in range(64))

    def is_valid(self):
        """Check if the API key is valid and not expired."""
        if not self.is_active:
            return False
        
        if self.expires_at and self.expires_at < timezone.now():
            return False
        
        return True

    def is_ip_allowed(self, ip_address):
        """Check if the given IP address is allowed to use this API key."""
        if not self.allowed_ips:
            return True
        
        allowed_ips = [ip.strip() for ip in self.allowed_ips.split(',')]
        return ip_address in allowed_ips

    def increment_usage(self):
        """Increment the usage counter."""
        self.request_count += 1
        self.last_used = timezone.now()
        self.save(update_fields=['request_count', 'last_used'])

    def has_permission(self, action):
        """Check if the API key has permission for the given action."""
        permission_map = {
            'GET': self.can_read,
            'POST': self.can_write,
            'PUT': self.can_write,
            'PATCH': self.can_write,
            'DELETE': self.can_delete,
        }
        return permission_map.get(action, False)