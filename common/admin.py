from django.contrib import admin
from .models import APIKey


@admin.register(APIKey)
class APIKeyAdmin(admin.ModelAdmin):
    list_display = ('name', 'prefix', 'user', 'is_active', 'can_read', 'can_write', 'can_delete', 'request_count', 'last_used', 'created_at')
    list_filter = ('is_active', 'can_read', 'can_write', 'can_delete', 'created_at')
    search_fields = ('name', 'prefix', 'user__email', 'user__username')
    readonly_fields = ('key', 'prefix', 'request_count', 'last_used', 'created_at', 'updated_at')
    raw_id_fields = ('user',)
    
    fieldsets = (
        (None, {
            'fields': ('name', 'user', 'key', 'prefix', 'is_active')
        }),
        ('Permissions', {
            'fields': ('can_read', 'can_write', 'can_delete')
        }),
        ('Security', {
            'fields': ('allowed_ips', 'expires_at', 'max_requests_per_hour')
        }),
        ('Usage Statistics', {
            'fields': ('request_count', 'last_used')
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    def save_model(self, request, obj, form, change):
        if not change:  # Only set created_by for new objects
            obj.created_by = request.user
        obj.updated_by = request.user
        super().save_model(request, obj, form, change)
