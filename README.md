# Django Base Project

A comprehensive Django base project with REST API, authentication, monitoring, and utilities for rapid development.

## Features

### Core Features
- ✅ Django 4.2 with PostgreSQL database
- ✅ Django REST Framework with JWT authentication
- ✅ Custom User model with profile management
- ✅ Docker and Docker Compose setup
- ✅ Environment-based configuration

### Authentication & Authorization
- ✅ JWT-based authentication with token rotation
- ✅ API Key authentication for service-to-service communication
- ✅ Combined authentication (JWT + API Key)
- ✅ User registration and login endpoints
- ✅ Social authentication (Google, Facebook)
- ✅ Password change functionality
- ✅ Django Admin panel with custom user admin

### API Features
- ✅ DRF Spectacular for OpenAPI schema
- ✅ Swagger UI at `/api/docs/`
- ✅ ReDoc at `/api/redoc/`
- ✅ API versioning strategy (v1, v2)
- ✅ Rate limiting on authentication endpoints
- ✅ Redis-based caching for improved performance

### Performance & Security
- ✅ Redis caching with multiple cache backends
- ✅ Rate limiting with django-ratelimit
- ✅ Session storage in Redis
- ✅ API response caching
- ✅ Database query optimization helpers

### Monitoring & Logging
- ✅ Sentry integration for error tracking
- ✅ Django Health Check endpoints
- ✅ Prometheus metrics collection
- ✅ Structured logging configuration
- ✅ Automated health check monitoring

### Communication
- ✅ Email backend with SendGrid support
- ✅ SMS functionality with Twilio integration
- ✅ Utility classes for email and SMS services

### File Storage
- ✅ Cloudflare R2 integration for media/static files
- ✅ Local file storage for development
- ✅ File upload validation and helpers

### Database & Backup
- ✅ PostgreSQL with connection pooling
- ✅ Automated database backup utilities
- ✅ Backup upload to cloud storage
- ✅ Scheduled cleanup tasks

### Code Quality & Testing
- ✅ Pre-commit hooks (Black, Flake8, isort, mypy, bandit)
- ✅ Comprehensive test suite with pytest
- ✅ Factory classes for test data generation
- ✅ Code coverage reporting
- ✅ Security scanning with bandit

### CI/CD & Deployment
- ✅ GitHub Actions CI/CD pipeline
- ✅ Automated testing on pull requests
- ✅ Security scanning and code quality checks
- ✅ Docker image building and publishing
- ✅ Production deployment workflow

### Task Scheduling
- ✅ Celery for background tasks
- ✅ Django-crontab for scheduled jobs
- ✅ Automated token cleanup
- ✅ Weekly backup scheduling

### Utilities
- ✅ Common utilities app with helper functions
- ✅ Custom permissions and mixins
- ✅ Base model classes with timestamps and audit trails
- ✅ File upload helpers and pagination utilities
- ✅ Response helpers for consistent API responses
- ✅ Caching utilities and decorators

### Development & Production
- ✅ Separate environment configurations
- ✅ Docker containerization with multi-service setup
- ✅ Static file handling with WhiteNoise
- ✅ CORS configuration
- ✅ Security settings optimized for production

## Quick Start

### Prerequisites
- Docker and Docker Compose
- Python 3.11+ (for local development)

### Using Docker (Recommended)

1. Clone the repository:
```bash
git clone <repository-url>
cd django-base-project
```

2. Copy environment file:
```bash
cp .env.example .env
```

3. Update the `.env` file with your configuration

4. Build and run with Docker Compose:
```bash
docker-compose up --build
```

5. Run migrations:
```bash
docker-compose exec web python manage.py migrate
```

6. Create a superuser:
```bash
docker-compose exec web python manage.py createsuperuser
```

### Local Development

1. Create and activate virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Set up your environment variables and run migrations:
```bash
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver
```

## API Endpoints

### Authentication
- `POST /api/users/register/` - User registration
- `POST /api/users/login/` - User login
- `POST /api/users/logout/` - User logout
- `POST /api/users/token/refresh/` - Refresh JWT token

### User Management
- `GET /api/users/profile/` - Get user profile
- `PUT /api/users/profile/update/` - Update user information
- `PUT /api/users/profile/details/` - Update profile details
- `POST /api/users/change-password/` - Change password

### Documentation
- `/api/docs/` - Swagger UI
- `/api/redoc/` - ReDoc
- `/api/schema/` - OpenAPI schema

### Monitoring
- `/health/` - Health check endpoints
- `/metrics/` - Prometheus metrics

## Environment Variables

See `.env.example` for all available environment variables. Key variables include:

- `SECRET_KEY` - Django secret key
- `DEBUG` - Debug mode (True/False)
- `DB_*` - Database configuration
- `REDIS_URL` - Redis connection string
- `SENTRY_DSN` - Sentry error tracking
- `EMAIL_*` - Email provider settings
- `TWILIO_*` - SMS provider settings
- Social auth credentials

## Project Structure

```
django-base-project/
├── config/                 # Project configuration
│   ├── settings.py         # Django settings
│   ├── urls.py            # Main URL configuration
│   └── celery.py          # Celery configuration
├── users/                 # User management app
│   ├── models.py          # User and Profile models
│   ├── serializers.py     # DRF serializers
│   ├── views.py           # API views
│   └── admin.py           # Admin configuration
├── common/                # Common utilities
│   ├── utils.py           # Helper functions
│   ├── permissions.py     # Custom permissions
│   └── mixins.py          # Model mixins
├── requirements.txt       # Python dependencies
├── docker-compose.yml     # Docker Compose configuration
├── Dockerfile            # Docker image configuration
└── .env.example          # Environment variables template
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License.