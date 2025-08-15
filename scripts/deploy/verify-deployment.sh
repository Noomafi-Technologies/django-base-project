#!/bin/bash

# Deployment Verification Script for Django Base Project
# This script verifies that the deployment is working correctly

set -e

# Configuration
DOMAIN=${1:-"localhost"}
PROTOCOL=${2:-"https"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ❌ ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] ℹ️  $1${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [domain] [protocol]"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Test localhost with HTTPS"
    echo "  $0 your-domain.com                   # Test your domain with HTTPS"
    echo "  $0 your-domain.com http              # Test your domain with HTTP"
    echo ""
    echo "This script will:"
    echo "  1. Verify Docker containers are running"
    echo "  2. Test health check endpoints"
    echo "  3. Verify SSL certificate (if HTTPS)"
    echo "  4. Test API endpoints"
    echo "  5. Check security headers"
    echo "  6. Validate performance metrics"
}

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    info "Running test: $test_name"
    
    if eval "$test_command" > /dev/null 2>&1; then
        if [ -n "$expected_result" ]; then
            local result=$(eval "$test_command" 2>/dev/null)
            if echo "$result" | grep -q "$expected_result"; then
                log "PASS: $test_name"
                TESTS_PASSED=$((TESTS_PASSED + 1))
                return 0
            else
                error "FAIL: $test_name (unexpected result)"
                TESTS_FAILED=$((TESTS_FAILED + 1))
                return 1
            fi
        else
            log "PASS: $test_name"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            return 0
        fi
    else
        error "FAIL: $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Function to test HTTP endpoint
test_endpoint() {
    local endpoint="$1"
    local expected_status="$2"
    local description="$3"
    
    local url="${PROTOCOL}://${DOMAIN}${endpoint}"
    local status_code
    
    status_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    
    if [ "$status_code" = "$expected_status" ]; then
        log "PASS: $description ($endpoint) - Status: $status_code"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        error "FAIL: $description ($endpoint) - Expected: $expected_status, Got: $status_code"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

echo ""
echo "🔍 Django Base Project Deployment Verification"
echo "=============================================="
echo "Domain: $DOMAIN"
echo "Protocol: $PROTOCOL"
echo "Timestamp: $(date)"
echo ""

# Check if domain is provided for certain tests
if [ "$DOMAIN" = "localhost" ] && [ "$PROTOCOL" = "https" ]; then
    warn "Testing HTTPS on localhost - SSL verification may fail"
fi

# 1. Docker Container Verification
info "🐳 Verifying Docker containers..."

if command -v docker-compose > /dev/null 2>&1; then
    # Check if containers are running
    if docker-compose ps | grep -q "Up"; then
        log "Docker containers are running"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        
        # List running containers
        info "Running containers:"
        docker-compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
    else
        error "No Docker containers are running"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
else
    warn "Docker Compose not found - skipping container verification"
fi

echo ""

# 2. Health Check Endpoints
info "🏥 Testing health check endpoints..."

test_endpoint "/health/" "200" "Main health check"
test_endpoint "/health/live/" "200" "Liveness probe"
test_endpoint "/health/ready/" "200" "Readiness probe"

echo ""

# 3. Core Application Endpoints
info "🚀 Testing core application endpoints..."

test_endpoint "/admin/" "200" "Django admin interface"
test_endpoint "/api/docs/" "200" "API documentation"
test_endpoint "/api/schema/" "200" "API schema"

echo ""

# 4. API Endpoints
info "🔌 Testing API endpoints..."

test_endpoint "/api/users/register/" "405" "User registration endpoint (method not allowed is expected)"
test_endpoint "/metrics/" "200" "Metrics endpoint"

echo ""

# 5. SSL Certificate Verification (if HTTPS)
if [ "$PROTOCOL" = "https" ] && [ "$DOMAIN" != "localhost" ]; then
    info "🔒 Verifying SSL certificate..."
    
    # Check SSL certificate
    ssl_info=$(echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        log "SSL certificate is valid"
        echo "$ssl_info" | while IFS= read -r line; do
            info "  $line"
        done
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        error "SSL certificate verification failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
fi

echo ""

# 6. Security Headers
info "🛡️  Testing security headers..."

if command -v curl > /dev/null 2>&1; then
    headers=$(curl -s -I "${PROTOCOL}://${DOMAIN}/health/" 2>/dev/null)
    
    # Check for important security headers
    if echo "$headers" | grep -qi "strict-transport-security"; then
        log "HSTS header present"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        warn "HSTS header missing"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if echo "$headers" | grep -qi "x-frame-options"; then
        log "X-Frame-Options header present"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        warn "X-Frame-Options header missing"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if echo "$headers" | grep -qi "x-content-type-options"; then
        log "X-Content-Type-Options header present"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        warn "X-Content-Type-Options header missing"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
fi

echo ""

# 7. Performance Test
info "⚡ Testing response times..."

if command -v curl > /dev/null 2>&1; then
    response_time=$(curl -o /dev/null -s -w "%{time_total}" "${PROTOCOL}://${DOMAIN}/health/" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        # Check if response time is under 2 seconds
        if [ "$(echo "$response_time < 2" | bc 2>/dev/null || echo "1")" = "1" ]; then
            log "Response time: ${response_time}s (Good)"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            warn "Response time: ${response_time}s (Slow)"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        error "Could not measure response time"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
fi

echo ""

# 8. Database Connectivity (if containers are running)
if command -v docker-compose > /dev/null 2>&1 && docker-compose ps db | grep -q "Up"; then
    info "🗄️  Testing database connectivity..."
    
    if docker-compose exec -T db pg_isready > /dev/null 2>&1; then
        log "Database is accessible"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        error "Database is not accessible"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
fi

echo ""

# Summary
echo "📊 Test Results Summary"
echo "======================="
echo "Total Tests: $TESTS_TOTAL"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo ""
    log "🎉 All tests passed! Deployment is healthy."
    echo ""
    echo "Next steps:"
    echo "1. Monitor application logs for any issues"
    echo "2. Set up automated monitoring and alerting"
    echo "3. Configure regular backups"
    echo "4. Review and optimize performance"
    exit 0
else
    echo ""
    error "Some tests failed. Please review the issues above."
    echo ""
    echo "Common troubleshooting steps:"
    echo "1. Check Docker container logs: docker-compose logs"
    echo "2. Verify environment variables are set correctly"
    echo "3. Ensure all services are running: docker-compose ps"
    echo "4. Check network connectivity and DNS resolution"
    echo "5. Verify SSL certificate configuration"
    exit 1
fi