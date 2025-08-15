import os
from django.conf import settings
from django.core.mail import send_mail
from twilio.rest import Client
import logging

logger = logging.getLogger(__name__)


class EmailService:
    @staticmethod
    def send_email(subject, message, recipient_list, from_email=None):
        try:
            if from_email is None:
                from_email = settings.DEFAULT_FROM_EMAIL
            
            send_mail(
                subject=subject,
                message=message,
                from_email=from_email,
                recipient_list=recipient_list,
                fail_silently=False,
            )
            logger.info(f"Email sent successfully to {recipient_list}")
            return True
        except Exception as e:
            logger.error(f"Failed to send email: {str(e)}")
            return False

    @staticmethod
    def send_welcome_email(user):
        subject = "Welcome to our platform!"
        message = f"""
        Hello {user.first_name},
        
        Welcome to our platform! We're excited to have you on board.
        
        Best regards,
        The Team
        """
        return EmailService.send_email(subject, message, [user.email])

    @staticmethod
    def send_password_reset_email(user, reset_link):
        subject = "Password Reset Request"
        message = f"""
        Hello {user.first_name},
        
        You requested a password reset. Click the link below to reset your password:
        {reset_link}
        
        If you didn't request this, please ignore this email.
        
        Best regards,
        The Team
        """
        return EmailService.send_email(subject, message, [user.email])


class SMSService:
    def __init__(self):
        self.client = None
        if hasattr(settings, 'TWILIO_ACCOUNT_SID') and settings.TWILIO_ACCOUNT_SID:
            self.client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)

    def send_sms(self, to_phone, message):
        if not self.client:
            logger.error("Twilio client not configured")
            return False
        
        try:
            message = self.client.messages.create(
                body=message,
                from_=settings.TWILIO_PHONE_NUMBER,
                to=to_phone
            )
            logger.info(f"SMS sent successfully to {to_phone}")
            return True
        except Exception as e:
            logger.error(f"Failed to send SMS: {str(e)}")
            return False

    def send_verification_code(self, phone_number, code):
        message = f"Your verification code is: {code}"
        return self.send_sms(phone_number, message)


class ResponseHelper:
    @staticmethod
    def success_response(data=None, message="Success"):
        response = {
            'success': True,
            'message': message
        }
        if data:
            response['data'] = data
        return response

    @staticmethod
    def error_response(message="Error", errors=None):
        response = {
            'success': False,
            'message': message
        }
        if errors:
            response['errors'] = errors
        return response


class FileUploadHelper:
    @staticmethod
    def get_upload_path(instance, filename):
        model_name = instance._meta.model_name
        return f"{model_name}s/{filename}"

    @staticmethod
    def validate_file_size(file, max_size_mb=5):
        if file.size > max_size_mb * 1024 * 1024:
            raise ValueError(f"File size exceeds {max_size_mb}MB limit")
        return True

    @staticmethod
    def validate_file_type(file, allowed_types):
        file_extension = os.path.splitext(file.name)[1].lower()
        if file_extension not in allowed_types:
            raise ValueError(f"File type {file_extension} not allowed")
        return True


class PaginationHelper:
    @staticmethod
    def paginate_queryset(queryset, page, page_size=20):
        from django.core.paginator import Paginator, EmptyPage, PageNotAnInteger
        
        paginator = Paginator(queryset, page_size)
        
        try:
            paginated_data = paginator.page(page)
        except PageNotAnInteger:
            paginated_data = paginator.page(1)
        except EmptyPage:
            paginated_data = paginator.page(paginator.num_pages)
        
        return {
            'data': paginated_data,
            'pagination': {
                'current_page': paginated_data.number,
                'total_pages': paginator.num_pages,
                'total_items': paginator.count,
                'has_next': paginated_data.has_next(),
                'has_previous': paginated_data.has_previous()
            }
        }