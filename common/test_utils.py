import pytest
from unittest.mock import patch, MagicMock
from django.contrib.auth import get_user_model
from django.test import override_settings
from common.utils import EmailService, SMSService, ResponseHelper, PaginationHelper

User = get_user_model()


class TestEmailService:
    @patch('common.utils.send_mail')
    def test_send_email_success(self, mock_send_mail):
        mock_send_mail.return_value = True
        
        result = EmailService.send_email(
            subject="Test Subject",
            message="Test Message",
            recipient_list=["test@example.com"]
        )
        
        assert result is True
        mock_send_mail.assert_called_once()

    @patch('common.utils.send_mail')
    def test_send_email_failure(self, mock_send_mail):
        mock_send_mail.side_effect = Exception("Email send failed")
        
        result = EmailService.send_email(
            subject="Test Subject",
            message="Test Message",
            recipient_list=["test@example.com"]
        )
        
        assert result is False

    @pytest.mark.django_db
    @patch('common.utils.EmailService.send_email')
    def test_send_welcome_email(self, mock_send_email):
        user = User.objects.create_user(
            email="test@example.com",
            username="testuser",
            first_name="Test",
            password="testpass123"
        )
        mock_send_email.return_value = True
        
        result = EmailService.send_welcome_email(user)
        
        assert result is True
        mock_send_email.assert_called_once()
        args, kwargs = mock_send_email.call_args
        assert "Welcome to our platform!" in args[0]
        assert "Test" in args[1]
        assert user.email in args[2]


class TestSMSService:
    @override_settings(
        TWILIO_ACCOUNT_SID="test_sid",
        TWILIO_AUTH_TOKEN="test_token",
        TWILIO_PHONE_NUMBER="+1234567890"
    )
    @patch('common.utils.Client')
    def test_send_sms_success(self, mock_client_class):
        mock_client = MagicMock()
        mock_client_class.return_value = mock_client
        mock_client.messages.create.return_value = MagicMock()
        
        sms_service = SMSService()
        result = sms_service.send_sms("+1987654321", "Test message")
        
        assert result is True
        mock_client.messages.create.assert_called_once()

    @override_settings(TWILIO_ACCOUNT_SID=None)
    def test_send_sms_no_config(self):
        sms_service = SMSService()
        result = sms_service.send_sms("+1987654321", "Test message")
        
        assert result is False


class TestResponseHelper:
    def test_success_response(self):
        response = ResponseHelper.success_response(
            data={"key": "value"},
            message="Test success"
        )
        
        assert response["success"] is True
        assert response["message"] == "Test success"
        assert response["data"] == {"key": "value"}

    def test_success_response_no_data(self):
        response = ResponseHelper.success_response(message="Test success")
        
        assert response["success"] is True
        assert response["message"] == "Test success"
        assert "data" not in response

    def test_error_response(self):
        response = ResponseHelper.error_response(
            message="Test error",
            errors={"field": ["error message"]}
        )
        
        assert response["success"] is False
        assert response["message"] == "Test error"
        assert response["errors"] == {"field": ["error message"]}


class TestPaginationHelper:
    @pytest.mark.django_db
    def test_paginate_queryset(self):
        # Create test users
        users = [
            User.objects.create_user(
                email=f"user{i}@example.com",
                username=f"user{i}",
                password="testpass123"
            )
            for i in range(25)
        ]
        
        queryset = User.objects.all()
        result = PaginationHelper.paginate_queryset(queryset, page=1, page_size=10)
        
        assert len(result["data"]) == 10
        assert result["pagination"]["current_page"] == 1
        assert result["pagination"]["total_pages"] == 3
        assert result["pagination"]["total_items"] == 25
        assert result["pagination"]["has_next"] is True
        assert result["pagination"]["has_previous"] is False

    @pytest.mark.django_db
    def test_paginate_queryset_last_page(self):
        # Create test users
        users = [
            User.objects.create_user(
                email=f"user{i}@example.com",
                username=f"user{i}",
                password="testpass123"
            )
            for i in range(25)
        ]
        
        queryset = User.objects.all()
        result = PaginationHelper.paginate_queryset(queryset, page=3, page_size=10)
        
        assert len(result["data"]) == 5
        assert result["pagination"]["current_page"] == 3
        assert result["pagination"]["has_next"] is False
        assert result["pagination"]["has_previous"] is True