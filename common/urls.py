from django.urls import path
from . import health_checks

app_name = 'common'

urlpatterns = [
    # Health check endpoints
    path('health/', health_checks.health_check, name='health_check'),
    path('health/live/', health_checks.liveness_probe, name='liveness_probe'),
    path('health/ready/', health_checks.readiness_probe, name='readiness_probe'),
    path('metrics/', health_checks.metrics_endpoint, name='metrics'),
]