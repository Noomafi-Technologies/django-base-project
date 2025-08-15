# Django Base Project - VPS Deployment Guide

This guide provides step-by-step instructions for deploying the Django Base Project to a VPS using Dokploy.

## 📋 Prerequisites

### VPS Requirements
- **Operating System**: Ubuntu 20.04 LTS or 22.04 LTS
- **RAM**: Minimum 2GB (4GB+ recommended for production)
- **Storage**: Minimum 20GB SSD (50GB+ recommended)
- **CPU**: 1 vCPU minimum (2+ recommended)
- **Network**: Public IP address with SSH access

### Domain & DNS
- Domain name pointing to your VPS IP address
- DNS A record configured: `your-domain.com` → `YOUR_VPS_IP`
- Optional subdomain: `api.your-domain.com` → `YOUR_VPS_IP`

### Local Requirements
- SSH access to your VPS
- Git access to this repository
- Domain management access for DNS configuration

## 🚀 Deployment Steps

### Step 1: Initial VPS Setup

#### 1.1 Connect to VPS
```bash
ssh root@YOUR_VPS_IP
# or if you have a non-root user:
ssh ubuntu@YOUR_VPS_IP
```

#### 1.2 Update System
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git htop unzip
```

#### 1.3 Configure Firewall
```bash
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 3000/tcp  # Dokploy dashboard
sudo ufw status
```

### Step 2: Install Docker

#### 2.1 Install Docker Engine
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
newgrp docker
```

#### 2.2 Install Docker Compose
```bash
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

#### 2.3 Verify Installation
```bash
docker --version
docker-compose --version
docker run hello-world
```

### Step 3: Install Dokploy

#### 3.1 Install Dokploy
```bash
curl -sSL https://dokploy.com/install.sh | sh
```

#### 3.2 Access Dokploy Dashboard
1. Open your browser and navigate to: `http://YOUR_VPS_IP:3000`
2. Complete the initial setup wizard
3. Create an admin account
4. Configure basic settings

### Step 4: Configure Domain and SSL

#### 4.1 DNS Configuration
Ensure your domain DNS is properly configured:
- **A Record**: `your-domain.com` → `YOUR_VPS_IP`
- **A Record**: `www.your-domain.com` → `YOUR_VPS_IP`
- **A Record**: `api.your-domain.com` → `YOUR_VPS_IP` (optional)

Wait for DNS propagation (5-30 minutes).

#### 4.2 SSL Certificate Setup
In Dokploy dashboard:
1. Navigate to **Settings** → **SSL**
2. Add domain: `your-domain.com`
3. Enable **Let's Encrypt** automatic SSL
4. Wait for certificate generation

### Step 5: Deploy Application

#### 5.1 Create New Application
1. In Dokploy dashboard, click **"New Application"**
2. Choose **"Git Repository"**
3. Enter repository URL: `https://github.com/Noomafi-Technologies/django-base-project.git`
4. Select branch: `main`
5. Set application name: `django-base-project`

#### 5.2 Configure Environment Variables

Add the following environment variables in Dokploy (replace with your actual values):

```env
# Django Core
SECRET_KEY=your-super-secret-production-key-generate-new-one
DEBUG=False
ALLOWED_HOSTS=your-domain.com,api.your-domain.com,www.your-domain.com,YOUR_VPS_IP
ENVIRONMENT=production

# Database
DB_NAME=django_base_prod
DB_USER=django_user
DB_PASSWORD=your-secure-database-password-here
DB_HOST=db
DB_PORT=5432
POSTGRES_DB=django_base_prod
POSTGRES_USER=django_user
POSTGRES_PASSWORD=your-secure-database-password-here

# Redis
REDIS_URL=redis://redis:6379/0

# Email (SendGrid recommended)
EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST=smtp.sendgrid.net
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=apikey
EMAIL_HOST_PASSWORD=your-sendgrid-api-key
DEFAULT_FROM_EMAIL=noreply@your-domain.com

# SMS (Twilio)
TWILIO_ACCOUNT_SID=your-twilio-account-sid
TWILIO_AUTH_TOKEN=your-twilio-auth-token
TWILIO_PHONE_NUMBER=your-twilio-phone-number

# Error Tracking (Sentry)
SENTRY_DSN=your-sentry-dsn-url
SENTRY_ENVIRONMENT=production

# Social Auth
GOOGLE_OAUTH2_CLIENT_ID=your-google-client-id
GOOGLE_OAUTH2_CLIENT_SECRET=your-google-client-secret
FACEBOOK_APP_ID=your-facebook-app-id
FACEBOOK_APP_SECRET=your-facebook-app-secret

# JWT
JWT_SECRET_KEY=generate-separate-jwt-secret-key
JWT_ACCESS_TOKEN_LIFETIME_MINUTES=60
JWT_REFRESH_TOKEN_LIFETIME_DAYS=7

# File Storage (Optional - Cloudflare R2)
USE_CLOUDFLARE_R2=false
CLOUDFLARE_R2_ACCESS_KEY_ID=your-r2-access-key
CLOUDFLARE_R2_SECRET_ACCESS_KEY=your-r2-secret-key
CLOUDFLARE_R2_BUCKET_NAME=your-bucket-name
CLOUDFLARE_R2_ENDPOINT_URL=https://your-account-id.r2.cloudflarestorage.com
CLOUDFLARE_R2_CUSTOM_DOMAIN=files.your-domain.com

# Security & Performance
CORS_ALLOWED_ORIGINS=https://your-domain.com,https://www.your-domain.com
CACHE_DEFAULT_TIMEOUT=300
BACKUP_RETENTION_DAYS=30
RATELIMIT_ENABLE=True

# Admin
DJANGO_SUPERUSER_EMAIL=admin@your-domain.com
DJANGO_SUPERUSER_USERNAME=admin
DJANGO_SUPERUSER_PASSWORD=secure-admin-password
```

#### 5.3 Configure Docker Compose
In Dokploy, set the Docker Compose file to: `docker-compose.prod.yml`

#### 5.4 Deploy Application
1. Click **"Deploy Application"** in Dokploy
2. Monitor deployment logs for any issues
3. Wait for all services to start

### Step 6: Post-Deployment Setup

#### 6.1 Run Database Migrations
```bash
docker-compose -f docker-compose.prod.yml exec web python manage.py migrate
```

#### 6.2 Create Superuser
```bash
docker-compose -f docker-compose.prod.yml exec web python manage.py createsuperuser
```

#### 6.3 Collect Static Files
```bash
docker-compose -f docker-compose.prod.yml exec web python manage.py collectstatic --noinput
```

#### 6.4 Test Application
- Visit: `https://your-domain.com`
- Admin: `https://your-domain.com/admin/`
- API Docs: `https://your-domain.com/api/docs/`
- Health Check: `https://your-domain.com/health/`

### Step 7: Configure Monitoring

#### 7.1 Set Up Health Monitoring
The application includes several health check endpoints:
- `/health/` - Comprehensive health check
- `/health/live/` - Liveness probe
- `/health/ready/` - Readiness probe
- `/metrics/` - Basic metrics

#### 7.2 Configure Log Monitoring
In Dokploy dashboard:
1. Go to **Monitoring** tab
2. Enable log collection for all services
3. Set up log retention policies
4. Configure alerts for errors

#### 7.3 Set Up Backup Monitoring
```bash
# Make backup scripts executable
chmod +x scripts/backup/*.sh

# Set up automated backups
./scripts/backup/setup-cron.sh daily

# Test backup system
./scripts/backup/backup.sh
```

### Step 8: Security Hardening

#### 8.1 Server Security
```bash
# Disable password authentication
sudo nano /etc/ssh/sshd_config
# Set: PasswordAuthentication no
sudo systemctl restart ssh

# Install fail2ban
sudo apt install fail2ban -y
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

#### 8.2 Update Nginx Configuration
Edit `nginx/default.conf` to replace `your-domain.com` with your actual domain:

```bash
# Update SSL certificate paths
ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

# Update server_name
server_name your-domain.com www.your-domain.com;
```

## 🧪 Testing Your Deployment

### Basic Functionality Tests
- [ ] Application loads at `https://your-domain.com`
- [ ] SSL certificate is valid (green lock in browser)
- [ ] Admin panel accessible at `/admin/`
- [ ] API documentation at `/api/docs/`
- [ ] Health checks pass at `/health/`
- [ ] User registration and login work
- [ ] API endpoints respond correctly

### Performance Tests
```bash
# Test response times
curl -w "@curl-format.txt" -o /dev/null -s https://your-domain.com/health/

# Test concurrent connections
ab -n 100 -c 10 https://your-domain.com/health/
```

### Security Tests
- [ ] HTTPS is enforced (HTTP redirects to HTTPS)
- [ ] Security headers are present
- [ ] Rate limiting is active
- [ ] No sensitive data exposed in responses

## 🔧 Configuration Files

Your deployment should include these key files:

### Required Files
- `docker-compose.prod.yml` - Production Docker configuration
- `Dockerfile.prod` - Optimized production Dockerfile
- `nginx/nginx.conf` - Nginx main configuration
- `nginx/default.conf` - Site-specific Nginx configuration
- `.env` - Production environment variables (created from template)

### Optional Files
- `scripts/backup/backup.sh` - Database backup script
- `scripts/backup/restore.sh` - Database restore script
- `scripts/backup/setup-cron.sh` - Automated backup setup

## 🚨 Troubleshooting

### Common Issues

#### Application Won't Start
```bash
# Check container logs
docker-compose -f docker-compose.prod.yml logs web
docker-compose -f docker-compose.prod.yml logs db

# Restart services
docker-compose -f docker-compose.prod.yml restart
```

#### Database Connection Issues
```bash
# Check database status
docker-compose -f docker-compose.prod.yml ps
docker-compose -f docker-compose.prod.yml logs db

# Reset database (CAUTION: This will delete all data)
docker-compose -f docker-compose.prod.yml down -v
docker-compose -f docker-compose.prod.yml up -d db
```

#### SSL Certificate Issues
```bash
# Check certificate status
docker-compose -f docker-compose.prod.yml logs certbot

# Manual certificate renewal
docker-compose -f docker-compose.prod.yml exec certbot certbot renew
```

#### Static Files Not Loading
```bash
# Collect static files again
docker-compose -f docker-compose.prod.yml exec web python manage.py collectstatic --noinput

# Check Nginx logs
docker-compose -f docker-compose.prod.yml logs nginx
```

### Getting Help

If you encounter issues:
1. Check the application logs
2. Verify environment variables
3. Ensure DNS is properly configured
4. Check firewall settings
5. Verify SSL certificate status

## 📚 Additional Resources

- [Django Deployment Checklist](https://docs.djangoproject.com/en/4.2/howto/deployment/checklist/)
- [Dokploy Documentation](https://dokploy.com/docs)
- [Docker Compose Production Guide](https://docs.docker.com/compose/production/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Nginx Security Guide](https://nginx.org/en/docs/http/securing_http_traffic_ssl.html)

## 🎯 Success Criteria

Your deployment is successful when:

- ✅ Application is accessible via HTTPS
- ✅ All services are running and healthy
- ✅ Database migrations are applied
- ✅ SSL certificate is valid and auto-renewing
- ✅ Health checks are passing
- ✅ Monitoring and logging are active
- ✅ Backups are configured and tested
- ✅ Security measures are in place

## 📝 Maintenance

### Regular Tasks
- Monitor application health and performance
- Review and rotate logs
- Test backup and restore procedures
- Update dependencies and security patches
- Monitor SSL certificate expiration
- Review security logs and access patterns

### Monthly Tasks
- Review backup retention and cleanup
- Update system packages
- Review and update environment variables
- Performance optimization review
- Security audit and updates

Your Django Base Project is now successfully deployed on your VPS using Dokploy! 🎉