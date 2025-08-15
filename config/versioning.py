from rest_framework.versioning import URLPathVersioning, NamespaceVersioning
from rest_framework.response import Response
from rest_framework import status


class CustomURLPathVersioning(URLPathVersioning):
    """
    Custom URL path versioning that supports version-specific logic.
    """
    default_version = 'v1'
    allowed_versions = ['v1', 'v2']
    version_param = 'version'
    
    def determine_version(self, request, *args, **kwargs):
        version = super().determine_version(request, *args, **kwargs)
        
        # Set version in request for easy access
        request.api_version = version
        
        return version
    
    def reverse(self, viewname, args=None, kwargs=None, request=None, format=None):
        """
        Override reverse to include version in URL.
        """
        if request.version:
            kwargs = kwargs or {}
            kwargs['version'] = request.version
        
        return super().reverse(viewname, args, kwargs, request, format)


class APIVersionMixin:
    """
    Mixin to add version-specific behavior to views.
    """
    
    def get_serializer_class(self):
        """
        Return different serializer classes based on API version.
        """
        version = getattr(self.request, 'version', 'v1')
        
        # Look for version-specific serializer
        version_serializer = getattr(self, f'serializer_class_{version}', None)
        if version_serializer:
            return version_serializer
        
        return super().get_serializer_class()
    
    def get_queryset(self):
        """
        Return different querysets based on API version.
        """
        version = getattr(self.request, 'version', 'v1')
        
        # Look for version-specific queryset method
        version_queryset_method = getattr(self, f'get_queryset_{version}', None)
        if version_queryset_method:
            return version_queryset_method()
        
        return super().get_queryset()
    
    def handle_deprecated_version(self):
        """
        Handle deprecated API versions with warnings.
        """
        version = getattr(self.request, 'version', 'v1')
        deprecated_versions = getattr(self, 'deprecated_versions', [])
        
        if version in deprecated_versions:
            # Add deprecation warning to response headers
            self.headers = getattr(self, 'headers', {})
            self.headers['X-API-Warning'] = f'API version {version} is deprecated'
            self.headers['X-API-Deprecation-Date'] = getattr(
                self, 
                f'deprecation_date_{version}', 
                'Unknown'
            )


def get_api_version_context(request):
    """
    Get version-specific context for serializers.
    """
    version = getattr(request, 'version', 'v1')
    
    return {
        'version': version,
        'is_v1': version == 'v1',
        'is_v2': version == 'v2',
        'request': request,
    }


class VersionedResponse:
    """
    Helper class for creating version-aware responses.
    """
    
    @staticmethod
    def success(data=None, message="Success", version=None):
        """
        Create a success response with version-specific format.
        """
        if version == 'v1':
            response_data = {
                'success': True,
                'message': message,
                'data': data
            }
        else:  # v2 and later
            response_data = {
                'status': 'success',
                'message': message,
                'result': data,
                'version': version
            }
        
        return Response(response_data, status=status.HTTP_200_OK)
    
    @staticmethod
    def error(message="Error", errors=None, version=None):
        """
        Create an error response with version-specific format.
        """
        if version == 'v1':
            response_data = {
                'success': False,
                'message': message,
                'errors': errors
            }
        else:  # v2 and later
            response_data = {
                'status': 'error',
                'message': message,
                'details': errors,
                'version': version
            }
        
        return Response(response_data, status=status.HTTP_400_BAD_REQUEST)