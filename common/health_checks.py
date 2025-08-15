"""
Custom health check endpoints for monitoring application status.
"""

import psutil
import redis
from django.conf import settings
from django.db import connections
from django.core.cache import cache
from django.http import JsonResponse
from django.shortcuts import render
from django.views.decorators.http import require_http_methods
from django.views.decorators.cache import never_cache
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework import status
import logging
from datetime import datetime

logger = logging.getLogger(__name__)


@never_cache
def health_check(request):
    """
    Comprehensive health check endpoint.
    Returns the overall health status of the application.
    Supports both JSON (API) and HTML (browser) responses based on Accept header.
    """
    try:
        checks = {
            'database': check_database(),
            'cache': check_cache(),
            'redis': check_redis(),
            'disk_space': check_disk_space(),
            'memory': check_memory(),
        }
        
        # Determine overall status
        overall_status = 'healthy'
        if any(not check['status'] for check in checks.values()):
            overall_status = 'unhealthy'
        elif any(check.get('warning', False) for check in checks.values()):
            overall_status = 'warning'
        
        response_data = {
            'status': overall_status,
            'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'checks': checks,
            'version': getattr(settings, 'VERSION', '1.0.0'),
        }
        
        # Check if browser request (wants HTML)
        accept_header = request.META.get('HTTP_ACCEPT', '')
        wants_html = 'text/html' in accept_header and 'application/json' not in accept_header
        
        if wants_html:
            # Prepare context for HTML template
            context = prepare_html_context(response_data)
            response = render(request, 'common/health_check.html', context)
            
            # Set appropriate status code for HTML response
            if overall_status != 'healthy':
                response.status_code = 503
            
            return response
        
        # Return JSON response for API clients
        status_code = 200 if overall_status == 'healthy' else 503
        return JsonResponse(response_data, status=status_code)
    
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        
        # Check if browser request for error response too
        accept_header = request.META.get('HTTP_ACCEPT', '')
        wants_html = 'text/html' in accept_header and 'application/json' not in accept_header
        
        if wants_html:
            context = {
                'status': 'error',
                'error_message': str(e),
                'version': getattr(settings, 'VERSION', '1.0.0'),
                'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            }
            response = render(request, 'common/health_check.html', context)
            response.status_code = 500
            return response
        
        return JsonResponse({
            'status': 'error',
            'message': 'Health check failed',
            'error': str(e)
        }, status=500)


def prepare_html_context(response_data):
    """
    Prepare context data for HTML template rendering.
    Adds visual status classes and human-readable labels.
    """
    status = response_data['status']
    checks = response_data['checks']
    
    # Map status to CSS classes and badge colors
    status_mapping = {
        'healthy': {'class': 'healthy', 'badge': 'success'},
        'warning': {'class': 'warning', 'badge': 'warning'},
        'unhealthy': {'class': 'unhealthy', 'badge': 'danger'},
        'error': {'class': 'unhealthy', 'badge': 'danger'},
    }
    
    overall_mapping = status_mapping.get(status, {'class': 'unknown', 'badge': 'secondary'})
    
    # Process each check to add UI-specific data
    processed_checks = {}
    for check_name, check_data in checks.items():
        check_status = check_data.get('status', False)
        check_warning = check_data.get('warning', False)
        
        if not check_status:
            check_class = 'unhealthy'
            check_badge = 'danger'
            check_text = 'Unhealthy'
        elif check_warning:
            check_class = 'warning'
            check_badge = 'warning'
            check_text = 'Warning'
        else:
            check_class = 'healthy'
            check_badge = 'success'
            check_text = 'Healthy'
        
        processed_checks[check_name] = {
            **check_data,
            'status_class': check_class,
            'badge_class': check_badge,
            'status_text': check_text,
        }
    
    context = {
        'status': status,
        'overall_status_class': overall_mapping['class'],
        'status_badge_class': overall_mapping['badge'],
        'checks': processed_checks,
        'version': response_data['version'],
        'timestamp': response_data['timestamp'],
        'project_name': getattr(settings, 'PROJECT_NAME', 'Django Base Project'),
    }
    
    return context


@api_view(['GET'])
@permission_classes([AllowAny])
@never_cache
def liveness_probe(request):
    """
    Simple liveness probe for Kubernetes/Docker health checks.
    Returns 200 if the application is running.
    """
    return Response({'status': 'alive'}, status=status.HTTP_200_OK)


@api_view(['GET'])
@permission_classes([AllowAny])
@never_cache
def readiness_probe(request):
    """
    Readiness probe to check if the application is ready to serve traffic.
    Checks critical dependencies.
    """
    try:
        # Check database connection
        db_status = check_database()
        if not db_status['status']:
            return Response({
                'status': 'not_ready',
                'reason': 'database_unavailable'
            }, status=status.HTTP_503_SERVICE_UNAVAILABLE)
        
        # Check cache
        cache_status = check_cache()
        if not cache_status['status']:
            return Response({
                'status': 'not_ready',
                'reason': 'cache_unavailable'
            }, status=status.HTTP_503_SERVICE_UNAVAILABLE)
        
        return Response({'status': 'ready'}, status=status.HTTP_200_OK)
    
    except Exception as e:
        logger.error(f"Readiness probe failed: {str(e)}")
        return Response({
            'status': 'not_ready',
            'reason': 'internal_error',
            'error': str(e)
        }, status=status.HTTP_503_SERVICE_UNAVAILABLE)


def check_database():
    """Check database connectivity and performance."""
    try:
        from django.db import connection
        
        # Test database connection
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            cursor.fetchone()
        
        # Get connection info
        db_info = {
            'status': True,
            'type': 'database',
            'vendor': connection.vendor,
            'queries_count': len(connection.queries) if settings.DEBUG else 'N/A',
        }
        
        return db_info
    
    except Exception as e:
        logger.error(f"Database health check failed: {str(e)}")
        return {
            'status': False,
            'type': 'database',
            'error': str(e)
        }


def check_cache():
    """Check cache connectivity and performance."""
    try:
        # Test cache set/get
        test_key = 'health_check_test'
        test_value = 'test_value'
        
        cache.set(test_key, test_value, timeout=10)
        retrieved_value = cache.get(test_key)
        
        if retrieved_value != test_value:
            raise Exception("Cache set/get test failed")
        
        # Clean up test key
        cache.delete(test_key)
        
        return {
            'status': True,
            'type': 'cache',
            'backend': cache.__class__.__name__,
        }
    
    except Exception as e:
        logger.error(f"Cache health check failed: {str(e)}")
        return {
            'status': False,
            'type': 'cache',
            'error': str(e)
        }


def check_redis():
    """Check Redis connectivity if available."""
    try:
        redis_url = getattr(settings, 'REDIS_URL', None)
        if not redis_url:
            return {
                'status': True,
                'type': 'redis',
                'message': 'Redis not configured'
            }
        
        # Connect to Redis
        r = redis.from_url(redis_url)
        
        # Test Redis ping
        response = r.ping()
        
        if not response:
            raise Exception("Redis ping failed")
        
        # Get Redis info
        info = r.info()
        
        return {
            'status': True,
            'type': 'redis',
            'version': info.get('redis_version', 'unknown'),
            'memory_usage': info.get('used_memory_human', 'unknown'),
            'connected_clients': info.get('connected_clients', 0),
        }
    
    except Exception as e:
        logger.error(f"Redis health check failed: {str(e)}")
        return {
            'status': False,
            'type': 'redis',
            'error': str(e)
        }


def check_disk_space():
    """Check available disk space."""
    try:
        disk_usage = psutil.disk_usage('/')
        
        # Calculate percentages
        total_gb = disk_usage.total / (1024**3)
        used_gb = disk_usage.used / (1024**3)
        free_gb = disk_usage.free / (1024**3)
        used_percent = (disk_usage.used / disk_usage.total) * 100
        
        # Get threshold from settings
        max_usage = getattr(settings, 'HEALTH_CHECK', {}).get('DISK_USAGE_MAX', 90)
        
        return {
            'status': used_percent < max_usage,
            'type': 'disk_space',
            'total_gb': round(total_gb, 2),
            'used_gb': round(used_gb, 2),
            'free_gb': round(free_gb, 2),
            'used_percent': round(used_percent, 2),
            'warning': used_percent > (max_usage - 10),  # Warning at 80%
        }
    
    except Exception as e:
        logger.error(f"Disk space health check failed: {str(e)}")
        return {
            'status': False,
            'type': 'disk_space',
            'error': str(e)
        }


def check_memory():
    """Check memory usage."""
    try:
        memory = psutil.virtual_memory()
        
        # Calculate values in MB
        total_mb = memory.total / (1024**2)
        available_mb = memory.available / (1024**2)
        used_mb = memory.used / (1024**2)
        used_percent = memory.percent
        
        # Get threshold from settings
        min_available = getattr(settings, 'HEALTH_CHECK', {}).get('MEMORY_MIN', 100)
        
        return {
            'status': available_mb > min_available,
            'type': 'memory',
            'total_mb': round(total_mb, 2),
            'used_mb': round(used_mb, 2),
            'available_mb': round(available_mb, 2),
            'used_percent': round(used_percent, 2),
            'warning': available_mb < (min_available * 2),  # Warning at 2x minimum
        }
    
    except Exception as e:
        logger.error(f"Memory health check failed: {str(e)}")
        return {
            'status': False,
            'type': 'memory',
            'error': str(e)
        }


@api_view(['GET'])
@permission_classes([AllowAny])
@never_cache
def metrics_endpoint(request):
    """
    Basic metrics endpoint for monitoring.
    """
    try:
        from django.db import connection
        
        metrics = {
            'database': {
                'queries_count': len(connection.queries) if settings.DEBUG else 'N/A',
                'vendor': connection.vendor,
            },
            'cache': {
                'backend': cache.__class__.__name__,
            },
            'system': {
                'cpu_percent': psutil.cpu_percent(interval=1),
                'memory_percent': psutil.virtual_memory().percent,
                'disk_percent': psutil.disk_usage('/').used / psutil.disk_usage('/').total * 100,
            }
        }
        
        return Response(metrics, status=status.HTTP_200_OK)
    
    except Exception as e:
        logger.error(f"Metrics endpoint failed: {str(e)}")
        return Response({
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)