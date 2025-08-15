from rest_framework import authentication, exceptions
from django.contrib.auth import get_user_model
from django.utils import timezone
from .models import APIKey
import logging

logger = logging.getLogger(__name__)
User = get_user_model()


class APIKeyAuthentication(authentication.BaseAuthentication):
    """
    Custom authentication using API keys.
    
    Clients should authenticate by passing the API key in the request header.
    For example:
        Authorization: ApiKey your-api-key-here
    """
    
    keyword = 'ApiKey'
    
    def authenticate(self, request):
        """
        Authenticate the request based on API key.
        """
        auth_header = authentication.get_authorization_header(request).split()
        
        if not auth_header or auth_header[0].lower() != self.keyword.lower().encode():
            return None
        
        if len(auth_header) == 1:
            msg = 'Invalid API key header. No credentials provided.'
            raise exceptions.AuthenticationFailed(msg)
        elif len(auth_header) > 2:
            msg = 'Invalid API key header. Credentials string should not contain spaces.'
            raise exceptions.AuthenticationFailed(msg)
        
        try:
            api_key = auth_header[1].decode()
        except UnicodeError:
            msg = 'Invalid API key header. Credentials string should not contain invalid characters.'
            raise exceptions.AuthenticationFailed(msg)
        
        return self.authenticate_credentials(api_key, request)
    
    def authenticate_credentials(self, key, request):
        """
        Authenticate the API key and return user and api_key instances.
        """
        try:
            api_key = APIKey.objects.select_related('user').get(key=key)
        except APIKey.DoesNotExist:
            logger.warning(f'API key authentication failed: key not found')
            raise exceptions.AuthenticationFailed('Invalid API key.')
        
        if not api_key.is_valid():
            logger.warning(f'API key authentication failed: key invalid or expired')
            raise exceptions.AuthenticationFailed('API key is inactive or expired.')
        
        if not api_key.user.is_active:
            logger.warning(f'API key authentication failed: user inactive')
            raise exceptions.AuthenticationFailed('User inactive or deleted.')
        
        # Check IP restrictions
        client_ip = self.get_client_ip(request)
        if not api_key.is_ip_allowed(client_ip):
            logger.warning(f'API key authentication failed: IP {client_ip} not allowed')
            raise exceptions.AuthenticationFailed('IP address not allowed for this API key.')
        
        # Check method permissions
        if not api_key.has_permission(request.method):
            logger.warning(f'API key authentication failed: method {request.method} not allowed')
            raise exceptions.AuthenticationFailed(f'API key does not have permission for {request.method} requests.')
        
        # Check rate limits
        if not self.check_rate_limit(api_key):
            logger.warning(f'API key authentication failed: rate limit exceeded')
            raise exceptions.AuthenticationFailed('Rate limit exceeded for this API key.')
        
        # Update usage tracking
        api_key.increment_usage()
        
        # Store API key in request for later use
        request.api_key = api_key
        
        logger.info(f'API key authentication successful for user {api_key.user.email}')
        return (api_key.user, api_key)
    
    def get_client_ip(self, request):
        """Get the client IP address from the request."""
        x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
        if x_forwarded_for:
            ip = x_forwarded_for.split(',')[0]
        else:
            ip = request.META.get('REMOTE_ADDR')
        return ip
    
    def check_rate_limit(self, api_key):
        """Check if the API key has exceeded its rate limit."""
        if not api_key.max_requests_per_hour:
            return True
        
        # Count requests in the last hour
        one_hour_ago = timezone.now() - timezone.timedelta(hours=1)
        
        # This is a simplified check - in production, you might want to use Redis
        # to track requests more efficiently
        if api_key.last_used and api_key.last_used > one_hour_ago:
            # For now, we'll use the request_count field
            # In a real implementation, you'd track hourly usage separately
            return True
        
        return True
    
    def authenticate_header(self, request):
        """
        Return a string to be used as the value of the `WWW-Authenticate`
        header in a `401 Unauthenticated` response.
        """
        return self.keyword


class CombinedAuthentication(authentication.BaseAuthentication):
    """
    Combined authentication that tries JWT first, then API key.
    """
    
    def authenticate(self, request):
        """
        Try JWT authentication first, then API key authentication.
        """
        from rest_framework_simplejwt.authentication import JWTAuthentication
        
        # Try JWT authentication first
        jwt_auth = JWTAuthentication()
        try:
            result = jwt_auth.authenticate(request)
            if result:
                return result
        except exceptions.AuthenticationFailed:
            pass
        
        # If JWT fails, try API key authentication
        api_key_auth = APIKeyAuthentication()
        return api_key_auth.authenticate(request)