import threading
from django.utils.deprecation import MiddlewareMixin

_thread_locals = threading.local()


class CurrentUserMiddleware(MiddlewareMixin):
    def process_request(self, request):
        _thread_locals.user = getattr(request, 'user', None)

    def process_response(self, request, response):
        if hasattr(_thread_locals, 'user'):
            del _thread_locals.user
        return response


def get_current_user():
    return getattr(_thread_locals, 'user', None)