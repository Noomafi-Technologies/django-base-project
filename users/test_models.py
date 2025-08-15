import pytest
from django.contrib.auth import get_user_model
from django.db import IntegrityError
from users.models import Profile

User = get_user_model()


@pytest.mark.django_db
class TestUserModel:
    def test_create_user(self):
        user = User.objects.create_user(
            email="test@example.com",
            username="testuser",
            first_name="Test",
            last_name="User",
            password="testpass123"
        )
        assert user.email == "test@example.com"
        assert user.username == "testuser"
        assert user.first_name == "Test"
        assert user.last_name == "User"
        assert user.check_password("testpass123")
        assert not user.is_staff
        assert not user.is_superuser
        assert user.is_active

    def test_create_superuser(self):
        admin_user = User.objects.create_superuser(
            email="admin@example.com",
            username="admin",
            first_name="Admin",
            last_name="User",
            password="adminpass123"
        )
        assert admin_user.email == "admin@example.com"
        assert admin_user.is_staff
        assert admin_user.is_superuser
        assert admin_user.is_active

    def test_email_unique(self):
        User.objects.create_user(
            email="test@example.com",
            username="testuser1",
            password="testpass123"
        )
        with pytest.raises(IntegrityError):
            User.objects.create_user(
                email="test@example.com",
                username="testuser2",
                password="testpass123"
            )

    def test_full_name_property(self):
        user = User.objects.create_user(
            email="test@example.com",
            username="testuser",
            first_name="John",
            last_name="Doe",
            password="testpass123"
        )
        assert user.full_name == "John Doe"

    def test_str_method(self):
        user = User.objects.create_user(
            email="test@example.com",
            username="testuser",
            password="testpass123"
        )
        assert str(user) == "test@example.com"


@pytest.mark.django_db
class TestProfileModel:
    def test_create_profile(self):
        user = User.objects.create_user(
            email="test@example.com",
            username="testuser",
            password="testpass123"
        )
        profile = Profile.objects.create(
            user=user,
            bio="Test bio",
            location="Test Location"
        )
        assert profile.user == user
        assert profile.bio == "Test bio"
        assert profile.location == "Test Location"

    def test_profile_str_method(self):
        user = User.objects.create_user(
            email="test@example.com",
            username="testuser",
            password="testpass123"
        )
        profile = Profile.objects.create(user=user)
        assert str(profile) == "test@example.com's Profile"