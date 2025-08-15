from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from . import views

app_name = 'users_v2'

# V2 might have different URL patterns or additional endpoints
urlpatterns = [
    path('register/', views.UserRegistrationView.as_view(), name='register'),
    path('login/', views.login_view, name='login'),
    path('logout/', views.logout_view, name='logout'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('profile/', views.UserProfileView.as_view(), name='profile'),
    path('profile/update/', views.UserUpdateView.as_view(), name='profile_update'),
    path('profile/details/', views.ProfileUpdateView.as_view(), name='profile_details'),
    path('change-password/', views.change_password, name='change_password'),
    path('users/', views.UserListView.as_view(), name='user_list'),  # Different URL in v2
    
    # V2 specific endpoints
    path('profile/avatar/', views.ProfileUpdateView.as_view(), name='profile_avatar'),
    path('bulk-update/', views.UserListView.as_view(), name='bulk_update'),
]