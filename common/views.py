from django.shortcuts import render
from django.http import JsonResponse
from django.views.decorators.http import require_http_methods
from django.views.decorators.cache import cache_page


def home(request):
    """
    Home page view with basic project information
    """
    context = {
        'project_name': 'Django Base Project',
        'version': '1.0.0',
        'description': 'A comprehensive Django base project with DRF, authentication, and deployment features',
        'features': [
            'Django REST Framework',
            'JWT Authentication',
            'Social Authentication (Google, Facebook)',
            'Custom User Model',
            'API Documentation',
            'Health Checks',
            'Docker Support',
            'Production-Ready Deployment',
            'Celery Background Tasks',
            'Redis Caching',
            'Rate Limiting',
            'Comprehensive Testing',
        ]
    }
    return render(request, 'common/home.html', context)


@require_http_methods(["GET"])
@cache_page(60 * 15)  # Cache for 15 minutes
def api_info(request):
    """
    API information endpoint
    """
    return JsonResponse({
        'name': 'Django Base Project API',
        'version': '1.0.0',
        'status': 'active',
        'endpoints': {
            'admin': '/admin/',
            'api_docs': '/api/docs/',
            'api_schema': '/api/schema/',
            'health': '/health/',
            'users': '/api/users/',
            'auth': '/api/auth/',
        },
        'features': [
            'REST API',
            'JWT Authentication',
            'Social Authentication',
            'User Management',
            'API Documentation',
            'Health Monitoring',
        ]
    })
