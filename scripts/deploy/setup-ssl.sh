#!/bin/bash

# SSL Certificate Setup Script for Django Base Project
# This script sets up SSL certificates using Let's Encrypt

set -e

# Configuration
DOMAIN=${1:-""}
EMAIL=${2:-""}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 <domain> <email>"
    echo ""
    echo "Examples:"
    echo "  $0 your-domain.com admin@your-domain.com"
    echo "  $0 api.your-domain.com webmaster@your-domain.com"
    echo ""
    echo "This script will:"
    echo "  1. Create SSL certificates using Let's Encrypt"
    echo "  2. Configure nginx for HTTPS"
    echo "  3. Set up automatic certificate renewal"
}

# Validate arguments
if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    error "Domain and email are required"
    show_usage
    exit 1
fi

# Validate email format
if ! echo "$EMAIL" | grep -E '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' > /dev/null; then
    error "Invalid email format: $EMAIL"
    exit 1
fi

log "Setting up SSL certificate for domain: $DOMAIN"
log "Contact email: $EMAIL"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    error "Docker is not running. Please start Docker first."
    exit 1
fi

# Check if nginx is running
if ! docker-compose ps nginx | grep -q "Up"; then
    warn "Nginx container is not running. Starting services..."
    docker-compose up -d nginx
    sleep 10
fi

# Create directories
mkdir -p ./certbot/conf
mkdir -p ./certbot/www

log "Creating initial certificate..."

# Get initial certificate
docker-compose run --rm certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    --force-renewal \
    -d "$DOMAIN"

if [ $? -eq 0 ]; then
    log "✅ SSL certificate created successfully for $DOMAIN"
else
    error "❌ Failed to create SSL certificate"
    exit 1
fi

# Update nginx configuration with the correct domain
log "Updating nginx configuration..."

# Create nginx config with the correct domain
cat > ./nginx/default.conf << EOF
# HTTP server - redirect to HTTPS
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    
    # Let's Encrypt challenge
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    # Redirect all other traffic to HTTPS
    location / {
        return 301 https://\$host\$request_uri;
    }
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;
    
    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    # SSL Security
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # HSTS
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header X-Download-Options "noopen" always;
    add_header X-Permitted-Cross-Domain-Policies "none" always;
    
    # Content Security Policy
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' https:; style-src 'self' 'unsafe-inline' https:; img-src 'self' data: https:; font-src 'self' https:; connect-src 'self' https:; frame-ancestors 'self';" always;
    
    # Static files
    location /static/ {
        alias /app/staticfiles/;
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
    
    # Media files
    location /media/ {
        alias /app/media/;
        expires 1M;
        add_header Cache-Control "public";
        access_log off;
    }
    
    # Health check endpoint
    location /health/ {
        proxy_pass http://web:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        access_log off;
    }
    
    # API endpoints with rate limiting
    location /api/ {
        # Basic rate limiting
        limit_req zone=api burst=20 nodelay;
        
        proxy_pass http://web:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Timeouts
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
    
    # Admin interface
    location /admin/ {
        proxy_pass http://web:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # All other requests
    location / {
        proxy_pass http://web:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Timeouts
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    # Security: Block access to sensitive files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    location ~ ~\$ {
        deny all;
        access_log off;
        log_not_found off;
    }
}
EOF

log "✅ Nginx configuration updated"

# Reload nginx
log "Reloading nginx..."
docker-compose exec nginx nginx -s reload

if [ $? -eq 0 ]; then
    log "✅ Nginx reloaded successfully"
else
    warn "Failed to reload nginx, restarting container..."
    docker-compose restart nginx
fi

# Test SSL certificate
log "Testing SSL certificate..."
sleep 5

if curl -fsS "https://$DOMAIN/health/" > /dev/null; then
    log "✅ SSL certificate is working correctly"
else
    warn "SSL test failed. Please check the configuration manually."
fi

# Set up automatic renewal
log "Setting up automatic certificate renewal..."

# Create renewal script
cat > ./scripts/deploy/renew-ssl.sh << 'EOF'
#!/bin/bash
# SSL Certificate Renewal Script

docker-compose run --rm certbot renew --quiet
if [ $? -eq 0 ]; then
    echo "Certificate renewed successfully"
    docker-compose exec nginx nginx -s reload
else
    echo "Certificate renewal failed"
    exit 1
fi
EOF

chmod +x ./scripts/deploy/renew-ssl.sh

# Add to crontab if not already present
CRON_JOB="0 12 * * * $(pwd)/scripts/deploy/renew-ssl.sh >> $(pwd)/logs/ssl-renewal.log 2>&1"

if ! crontab -l 2>/dev/null | grep -q "renew-ssl.sh"; then
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    log "✅ Automatic certificate renewal configured (daily at 12:00 PM)"
else
    log "ℹ️ Automatic certificate renewal already configured"
fi

# Create log directory
mkdir -p ./logs

log "🎉 SSL setup completed successfully!"
echo ""
echo "=== SSL SETUP SUMMARY ==="
echo "Domain: $DOMAIN"
echo "Certificate location: ./certbot/conf/live/$DOMAIN/"
echo "Nginx config: ./nginx/default.conf"
echo "Renewal script: ./scripts/deploy/renew-ssl.sh"
echo "Auto-renewal: Configured (daily at 12:00 PM)"
echo ""
echo "Next steps:"
echo "1. Test your site: https://$DOMAIN"
echo "2. Verify SSL grade: https://www.ssllabs.com/ssltest/analyze.html?d=$DOMAIN"
echo "3. Check renewal: ./scripts/deploy/renew-ssl.sh"
echo "========================="