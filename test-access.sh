#!/bin/bash

# Test access script
# Usage: ./test-access.sh

STACK_NAME="ios-safari-remote-debug"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_header "Testing Access"

# 1. Check if stack exists
echo "1. Checking stack..."
if docker stack ls | grep -q "$STACK_NAME"; then
    print_info "Stack exists"
else
    print_error "Stack not found! Deploy it first: ./deploy.sh"
    exit 1
fi
echo ""

# 2. Check services
echo "2. Checking services..."
APP_SERVICE="${STACK_NAME}_app"
CADDY_SERVICE="${STACK_NAME}_caddy"

APP_RUNNING=false
CADDY_RUNNING=false

if docker service ls | grep -q "$APP_SERVICE"; then
    REPLICAS=$(docker service ls --filter "name=$APP_SERVICE" --format "{{.Replicas}}")
    if echo "$REPLICAS" | grep -q "1/1"; then
        print_info "App service is running ($REPLICAS)"
        APP_RUNNING=true
    else
        print_warn "App service exists but not fully running ($REPLICAS)"
        docker service ps $APP_SERVICE --no-trunc | head -3
    fi
else
    print_error "App service not found!"
fi

if docker service ls | grep -q "$CADDY_SERVICE"; then
    REPLICAS=$(docker service ls --filter "name=$CADDY_SERVICE" --format "{{.Replicas}}")
    if echo "$REPLICAS" | grep -q "1/1"; then
        print_info "Caddy service is running ($REPLICAS)"
        CADDY_RUNNING=true
    else
        print_warn "Caddy service exists but not fully running ($REPLICAS)"
        docker service ps $CADDY_SERVICE --no-trunc | head -3
    fi
else
    print_error "Caddy service not found!"
fi
echo ""

# 3. Check ports
echo "3. Checking exposed ports..."
CADDY_PORTS=$(docker service ls --filter "name=$CADDY_SERVICE" --format "{{.Ports}}" 2>/dev/null || echo "")
if [ ! -z "$CADDY_PORTS" ] && [ "$CADDY_PORTS" != "<no value>" ]; then
    print_info "Caddy ports: $CADDY_PORTS"
    # Extract port numbers - handle format like "*:8080->80/tcp"
    HTTP_PORT=$(echo "$CADDY_PORTS" | grep -oE "[0-9]+->80" | head -1 | cut -d'>' -f1 | grep -oE "^[0-9]+" || echo "80")
    HTTPS_PORT=$(echo "$CADDY_PORTS" | grep -oE "[0-9]+->443" | head -1 | cut -d'>' -f1 | grep -oE "^[0-9]+" || echo "443")
    
    # Validate ports are numbers
    if ! [[ "$HTTP_PORT" =~ ^[0-9]+$ ]]; then
        HTTP_PORT="80"
    fi
    if ! [[ "$HTTPS_PORT" =~ ^[0-9]+$ ]]; then
        HTTPS_PORT="443"
    fi
    
    print_info "HTTP port: $HTTP_PORT"
    print_info "HTTPS port: $HTTPS_PORT"
else
    print_warn "No ports exposed for Caddy"
    HTTP_PORT="80"
    HTTPS_PORT="443"
fi
echo ""

# 4. Test app service internally
echo "4. Testing app service (internal)..."
if [ "$APP_RUNNING" = true ]; then
    # Try to curl from within network
    TEST_RESULT=$(docker run --rm --network ${STACK_NAME}_caddy-network curlimages/curl:latest curl -s -o /dev/null -w "%{http_code}" http://app:8924/ 2>/dev/null || echo "000")
    if [ "$TEST_RESULT" = "200" ] || [ "$TEST_RESULT" = "301" ] || [ "$TEST_RESULT" = "302" ]; then
        print_info "App is responding (HTTP $TEST_RESULT)"
    else
        print_error "App is not responding (HTTP $TEST_RESULT)"
        echo "   Check logs: docker service logs ${APP_SERVICE}"
    fi
else
    print_warn "Skipping app test (service not running)"
fi
echo ""

# 5. Test Caddy service
echo "5. Testing Caddy service..."
if [ "$CADDY_RUNNING" = true ]; then
    # Test Caddy admin API
    TEST_RESULT=$(docker run --rm --network ${STACK_NAME}_caddy-network curlimages/curl:latest curl -s -o /dev/null -w "%{http_code}" http://caddy:2019/config/ 2>/dev/null || echo "000")
    if [ "$TEST_RESULT" = "200" ] || [ "$TEST_RESULT" = "401" ]; then
        print_info "Caddy is responding (HTTP $TEST_RESULT)"
    else
        print_warn "Caddy might not be ready (HTTP $TEST_RESULT)"
    fi
else
    print_warn "Skipping Caddy test (service not running)"
fi
echo ""

# 6. Test external access
echo "6. Testing external access..."
# Get server IP (compatible with both Linux and macOS)
if command -v hostname &> /dev/null; then
    # Try Linux style first
    SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "")
    # If that fails, try macOS style
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "localhost")
    fi
else
    SERVER_IP="localhost"
fi

# Fallback to localhost if still empty
[ -z "$SERVER_IP" ] && SERVER_IP="localhost"

# Build test URL
if [ "$HTTP_PORT" != "80" ] && [ ! -z "$HTTP_PORT" ]; then
    TEST_URL="http://${SERVER_IP}:${HTTP_PORT}"
else
    TEST_URL="http://${SERVER_IP}"
fi

print_info "Testing: $TEST_URL"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$TEST_URL" 2>/dev/null || echo "000")

# Also test HTTPS
if [ "$HTTPS_PORT" != "443" ] && [ ! -z "$HTTPS_PORT" ]; then
    HTTPS_URL="https://${SERVER_IP}:${HTTPS_PORT}"
else
    HTTPS_URL="https://${SERVER_IP}"
fi

# Test HTTPS (ignore cert errors for localhost)
HTTPS_CODE=$(curl -s -o /dev/null -w "%{http_code}" -k --connect-timeout 5 --max-time 10 "$HTTPS_URL" 2>/dev/null || echo "000")

# Check if service is accessible
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
    print_info "✓ HTTP Accessible! (HTTP $HTTP_CODE)"
    echo ""
    echo "✅ You can access at:"
    echo "  - http://localhost:${HTTP_PORT}"
    if [ "$SERVER_IP" != "localhost" ]; then
        echo "  - http://${SERVER_IP}:${HTTP_PORT}"
    fi
    echo ""
    if [ "$HTTPS_CODE" = "200" ]; then
        print_info "✓ HTTPS also accessible!"
        if [ "$HTTPS_PORT" != "443" ] && [ ! -z "$HTTPS_PORT" ]; then
            echo "  - https://localhost:${HTTPS_PORT}"
        else
            echo "  - https://localhost"
        fi
    elif [ "$HTTPS_CODE" = "502" ] || [ "$HTTPS_CODE" = "503" ]; then
        print_warn "HTTPS returned $HTTPS_CODE (service might still be starting)"
        echo "   Try HTTP first: http://localhost:${HTTP_PORT}"
    fi
else
    print_error "Not accessible! (HTTP $HTTP_CODE)"
    echo ""
    echo "Possible issues:"
    echo "1. Firewall blocking ports $HTTP_PORT/$HTTPS_PORT"
    echo "2. Service not fully started (wait a bit and try again)"
    echo "3. Wrong port configuration"
    echo ""
    echo "Check logs:"
    echo "  docker service logs ${CADDY_SERVICE}"
fi
echo ""

# 7. Check Caddyfile
echo "7. Checking Caddyfile..."
if [ -f "Caddyfile" ]; then
    if grep -q "your-domain.com" Caddyfile; then
        print_warn "Caddyfile still contains 'your-domain.com'"
        echo "   Update it with your actual domain or use 'localhost' for testing"
    else
        DOMAIN=$(grep -E "^[a-zA-Z0-9.-]+ {" Caddyfile | head -1 | cut -d' ' -f1 || echo "unknown")
        print_info "Caddyfile configured for: $DOMAIN"
    fi
else
    print_error "Caddyfile not found!"
fi
echo ""

# Summary
print_header "Summary"
echo ""
if [ "$APP_RUNNING" = true ] && [ "$CADDY_RUNNING" = true ]; then
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
        print_info "Everything looks good! Service is accessible."
        echo ""
        echo "✅ Access URLs:"
        echo "  - http://localhost:${HTTP_PORT}"
        if [ "$SERVER_IP" != "localhost" ]; then
            echo "  - http://${SERVER_IP}:${HTTP_PORT}"
        fi
        if [ "$HTTPS_PORT" != "443" ] && [ ! -z "$HTTPS_PORT" ]; then
            echo "  - https://localhost:${HTTPS_PORT}"
            [ "$SERVER_IP" != "localhost" ] && echo "  - https://${SERVER_IP}:${HTTPS_PORT}"
        else
            echo "  - https://localhost"
            [ "$SERVER_IP" != "localhost" ] && echo "  - https://${SERVER_IP}"
        fi
        DOMAIN=$(grep -E "^[a-zA-Z0-9.-]+ {" Caddyfile 2>/dev/null | head -1 | cut -d' ' -f1 || echo "")
        [ ! -z "$DOMAIN" ] && [ "$DOMAIN" != "your-domain.com" ] && echo "  - http://${DOMAIN}:${HTTP_PORT}"
    else
        print_warn "Services are running but external test failed"
        echo ""
        echo "Services are running. Try accessing directly:"
        echo "  - http://localhost:${HTTP_PORT}"
        if [ "$HTTPS_PORT" != "443" ] && [ ! -z "$HTTPS_PORT" ]; then
            echo "  - https://localhost:${HTTPS_PORT}"
        else
            echo "  - https://localhost"
        fi
        echo ""
        echo "If still not accessible:"
        echo "  1. Wait a few more seconds for services to fully start"
        echo "  2. Check logs: ./logs.sh all"
        echo "  3. Check if port ${HTTP_PORT} is accessible: curl -I http://localhost:${HTTP_PORT}"
    fi
else
    print_error "Service is not accessible!"
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Check logs: ./logs.sh all"
    echo "2. Check status: ./status.sh"
    echo "3. Check firewall: sudo ufw status"
    echo "4. Try redeploy: ./redeploy.sh"
fi
echo ""

