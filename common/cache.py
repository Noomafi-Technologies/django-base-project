from django.core.cache import cache, caches
from django.conf import settings
from functools import wraps
import hashlib
import json
import logging

logger = logging.getLogger(__name__)


class CacheHelper:
    """Helper class for caching operations."""
    
    @staticmethod
    def get_cache_key(prefix, *args, **kwargs):
        """Generate a consistent cache key."""
        key_data = {
            'args': args,
            'kwargs': sorted(kwargs.items())
        }
        key_string = json.dumps(key_data, sort_keys=True)
        key_hash = hashlib.md5(key_string.encode()).hexdigest()
        return f"{prefix}:{key_hash}"
    
    @staticmethod
    def set_cache(key, value, timeout=None, cache_alias='default'):
        """Set a cache value with optional timeout."""
        try:
            cache_instance = caches[cache_alias]
            cache_instance.set(key, value, timeout)
            logger.debug(f"Cache set: {key}")
            return True
        except Exception as e:
            logger.error(f"Cache set error for key {key}: {str(e)}")
            return False
    
    @staticmethod
    def get_cache(key, default=None, cache_alias='default'):
        """Get a cache value."""
        try:
            cache_instance = caches[cache_alias]
            value = cache_instance.get(key, default)
            logger.debug(f"Cache get: {key} -> {'HIT' if value != default else 'MISS'}")
            return value
        except Exception as e:
            logger.error(f"Cache get error for key {key}: {str(e)}")
            return default
    
    @staticmethod
    def delete_cache(key, cache_alias='default'):
        """Delete a cache value."""
        try:
            cache_instance = caches[cache_alias]
            cache_instance.delete(key)
            logger.debug(f"Cache deleted: {key}")
            return True
        except Exception as e:
            logger.error(f"Cache delete error for key {key}: {str(e)}")
            return False
    
    @staticmethod
    def clear_cache_pattern(pattern, cache_alias='default'):
        """Clear cache keys matching a pattern."""
        try:
            cache_instance = caches[cache_alias]
            if hasattr(cache_instance, 'delete_pattern'):
                cache_instance.delete_pattern(f"*{pattern}*")
                logger.debug(f"Cache pattern cleared: {pattern}")
                return True
        except Exception as e:
            logger.error(f"Cache pattern clear error for pattern {pattern}: {str(e)}")
            return False


def cache_result(timeout=300, cache_alias='api', key_prefix='func'):
    """
    Decorator to cache function results.
    
    Args:
        timeout: Cache timeout in seconds (default: 5 minutes)
        cache_alias: Cache alias to use (default: 'api')
        key_prefix: Prefix for cache key (default: 'func')
    """
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            # Generate cache key
            cache_key = CacheHelper.get_cache_key(
                f"{key_prefix}:{func.__name__}",
                *args,
                **kwargs
            )
            
            # Try to get from cache
            cached_result = CacheHelper.get_cache(cache_key, cache_alias=cache_alias)
            if cached_result is not None:
                logger.debug(f"Cache hit for function {func.__name__}")
                return cached_result
            
            # Execute function and cache result
            result = func(*args, **kwargs)
            CacheHelper.set_cache(cache_key, result, timeout, cache_alias)
            logger.debug(f"Function {func.__name__} result cached")
            
            return result
        return wrapper
    return decorator


def invalidate_cache_on_save(model_name, cache_patterns=None):
    """
    Decorator to invalidate cache when model instances are saved.
    
    Args:
        model_name: Name of the model
        cache_patterns: List of cache patterns to invalidate
    """
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            result = func(*args, **kwargs)
            
            # Invalidate cache patterns
            if cache_patterns:
                for pattern in cache_patterns:
                    CacheHelper.clear_cache_pattern(pattern)
                    logger.debug(f"Invalidated cache pattern: {pattern}")
            
            # Invalidate model-specific cache
            model_pattern = f"{model_name.lower()}"
            CacheHelper.clear_cache_pattern(model_pattern)
            
            return result
        return wrapper
    return decorator


class CachedQuerySet:
    """Helper for caching QuerySet results."""
    
    def __init__(self, queryset, timeout=300, cache_alias='api'):
        self.queryset = queryset
        self.timeout = timeout
        self.cache_alias = cache_alias
    
    def cache_key(self, suffix=''):
        """Generate cache key for this queryset."""
        model_name = self.queryset.model.__name__.lower()
        query_hash = hashlib.md5(str(self.queryset.query).encode()).hexdigest()[:10]
        return f"queryset:{model_name}:{query_hash}{suffix}"
    
    def get_cached_results(self):
        """Get cached queryset results."""
        cache_key = self.cache_key(':results')
        cached_results = CacheHelper.get_cache(cache_key, cache_alias=self.cache_alias)
        
        if cached_results is not None:
            logger.debug(f"QuerySet cache hit: {self.queryset.model.__name__}")
            return cached_results
        
        # Execute queryset and cache results
        results = list(self.queryset)
        CacheHelper.set_cache(cache_key, results, self.timeout, self.cache_alias)
        logger.debug(f"QuerySet results cached: {self.queryset.model.__name__}")
        
        return results
    
    def get_cached_count(self):
        """Get cached count for this queryset."""
        cache_key = self.cache_key(':count')
        cached_count = CacheHelper.get_cache(cache_key, cache_alias=self.cache_alias)
        
        if cached_count is not None:
            logger.debug(f"QuerySet count cache hit: {self.queryset.model.__name__}")
            return cached_count
        
        # Get count and cache it
        count = self.queryset.count()
        CacheHelper.set_cache(cache_key, count, self.timeout, self.cache_alias)
        logger.debug(f"QuerySet count cached: {self.queryset.model.__name__}")
        
        return count
    
    def invalidate(self):
        """Invalidate cache for this queryset."""
        CacheHelper.delete_cache(self.cache_key(':results'), self.cache_alias)
        CacheHelper.delete_cache(self.cache_key(':count'), self.cache_alias)


def cached_property_redis(timeout=300, cache_alias='default'):
    """
    Redis-backed cached property decorator.
    
    Args:
        timeout: Cache timeout in seconds
        cache_alias: Cache alias to use
    """
    def decorator(func):
        @property
        def wrapper(self):
            # Generate cache key based on object and method
            cache_key = f"property:{self.__class__.__name__}:{self.pk}:{func.__name__}"
            
            # Try to get from cache
            cached_value = CacheHelper.get_cache(cache_key, cache_alias=cache_alias)
            if cached_value is not None:
                return cached_value
            
            # Compute value and cache it
            value = func(self)
            CacheHelper.set_cache(cache_key, value, timeout, cache_alias)
            
            return value
        
        return wrapper
    return decorator