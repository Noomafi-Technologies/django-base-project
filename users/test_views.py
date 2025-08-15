import pytest
from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken
from users.models import Profile

User = get_user_model()


@pytest.mark.django_db
class TestUserRegistrationView:
    def test_register_user_success(self):
        client = APIClient()
        url = reverse('users:register')
        data = {
            'email': 'newuser@example.com',
            'username': 'newuser',
            'first_name': 'New',
            'last_name': 'User',
            'password': 'strongpassword123',
            'password_confirm': 'strongpassword123'
        }
        response = client.post(url, data, format='json')
        
        assert response.status_code == status.HTTP_201_CREATED
        assert 'user' in response.data
        assert 'tokens' in response.data
        assert response.data['user']['email'] == 'newuser@example.com'
        
        # Check user was created
        user = User.objects.get(email='newuser@example.com')
        assert user.username == 'newuser'
        
        # Check profile was created
        assert Profile.objects.filter(user=user).exists()

    def test_register_user_password_mismatch(self):
        client = APIClient()
        url = reverse('users:register')
        data = {
            'email': 'newuser@example.com',
            'username': 'newuser',
            'first_name': 'New',
            'last_name': 'User',
            'password': 'strongpassword123',
            'password_confirm': 'differentpassword'
        }
        response = client.post(url, data, format='json')
        
        assert response.status_code == status.HTTP_400_BAD_REQUEST

    def test_register_user_duplicate_email(self):
        User.objects.create_user(
            email='existing@example.com',
            username='existing',
            password='password123'
        )
        
        client = APIClient()
        url = reverse('users:register')
        data = {
            'email': 'existing@example.com',
            'username': 'newuser',
            'first_name': 'New',
            'last_name': 'User',
            'password': 'strongpassword123',
            'password_confirm': 'strongpassword123'
        }
        response = client.post(url, data, format='json')
        
        assert response.status_code == status.HTTP_400_BAD_REQUEST


@pytest.mark.django_db
class TestUserLoginView:
    def test_login_success(self):
        user = User.objects.create_user(
            email='test@example.com',
            username='testuser',
            password='testpass123'
        )
        
        client = APIClient()
        url = reverse('users:login')
        data = {
            'email': 'test@example.com',
            'password': 'testpass123'
        }
        response = client.post(url, data, format='json')
        
        assert response.status_code == status.HTTP_200_OK
        assert 'user' in response.data
        assert 'tokens' in response.data
        assert response.data['user']['email'] == 'test@example.com'

    def test_login_invalid_credentials(self):
        User.objects.create_user(
            email='test@example.com',
            username='testuser',
            password='testpass123'
        )
        
        client = APIClient()
        url = reverse('users:login')
        data = {
            'email': 'test@example.com',
            'password': 'wrongpassword'
        }
        response = client.post(url, data, format='json')
        
        assert response.status_code == status.HTTP_400_BAD_REQUEST


@pytest.mark.django_db
class TestUserProfileView:
    def test_get_profile_authenticated(self):
        user = User.objects.create_user(
            email='test@example.com',
            username='testuser',
            first_name='Test',
            last_name='User',
            password='testpass123'
        )
        Profile.objects.create(user=user, bio='Test bio')
        
        client = APIClient()
        refresh = RefreshToken.for_user(user)
        client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        url = reverse('users:profile')
        response = client.get(url)
        
        assert response.status_code == status.HTTP_200_OK
        assert response.data['email'] == 'test@example.com'
        assert response.data['profile']['bio'] == 'Test bio'

    def test_get_profile_unauthenticated(self):
        client = APIClient()
        url = reverse('users:profile')
        response = client.get(url)
        
        assert response.status_code == status.HTTP_401_UNAUTHORIZED


@pytest.mark.django_db
class TestUserLogoutView:
    def test_logout_success(self):
        user = User.objects.create_user(
            email='test@example.com',
            username='testuser',
            password='testpass123'
        )
        
        client = APIClient()
        refresh = RefreshToken.for_user(user)
        client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        url = reverse('users:logout')
        data = {'refresh_token': str(refresh)}
        response = client.post(url, data, format='json')
        
        assert response.status_code == status.HTTP_200_OK
        assert response.data['message'] == 'Logout successful'