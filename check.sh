#!/bin/bash

# Troubleshooting script
# Usage: ./check.sh

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

echo ""
print_header "Troubleshooting Check"
echo ""

# 1. Check Docker
echo "1. Checking Docker..."
if command -v docker &> /dev/null; then
    print_info "Docker is installed"
    docker --version
else
    print_error "Docker is not installed!"
    exit 1
fi
echo ""

# 2. Check Docker Swarm
echo "2. Checking Docker Swarm..."
if docker info | grep -q "Swarm: active"; then
    print_info "Docker Swarm is active"
    docker info | grep -A 3 "Swarm:"
else
    print_warn "Docker Swarm is not active"
    echo "   Run: ./init-swarm.sh"
fi
echo ""

# 3. Check Stack
echo "3. Checking Stack..."
if docker stack ls | grep -q "$STACK_NAME"; then
    print_info "Stack $STACK_NAME exists"
    docker stack services $STACK_NAME
else
    print_error "Stack $STACK_NAME not found!"
    echo "   Run: ./deploy.sh"
    exit 1
fi
echo ""

# 4. Check Services
echo "4. Checking Services..."
APP_SERVICE="${STACK_NAME}_app"
CADDY_SERVICE="${STACK_NAME}_caddy"

if docker service ls | grep -q "$APP_SERVICE"; then
    print_info "App service exists"
    docker service ps $APP_SERVICE --no-trunc | head -3
else
    print_error "App service not found!"
fi

if docker service ls | grep -q "$CADDY_SERVICE"; then
    print_info "Caddy service exists"
    docker service ps $CADDY_SERVICE --no-trunc | head -3
else
    print_error "Caddy service not found!"
    echo ""
    print_warn "Common cause: Port conflict (80/443 already in use)"
    echo "   Check: docker service ls | grep -E '80|443'"
    echo "   Solution: ./fix-ports.sh"
fi
echo ""

# 5. Check Tasks Status
echo "5. Checking Tasks Status..."
TASKS=$(docker stack ps $STACK_NAME --format "{{.Name}}: {{.CurrentState}}")
if echo "$TASKS" | grep -q "Running"; then
    print_info "Some tasks are running"
else
    print_warn "No tasks are running!"
fi

# Check for errors
if echo "$TASKS" | grep -q "Failed\|Rejected"; then
    print_error "Some tasks have failed!"
    docker stack ps $STACK_NAME --filter "desired-state=running" --no-trunc
fi
echo ""

# 6. Check Ports
echo "6. Checking Ports..."
if netstat -tuln 2>/dev/null | grep -q ":80 "; then
    print_info "Port 80 is in use"
else
    print_warn "Port 80 is not in use (might be normal if using Docker)"
fi

if netstat -tuln 2>/dev/null | grep -q ":443 "; then
    print_info "Port 443 is in use"
else
    print_warn "Port 443 is not in use (might be normal if using Docker)"
fi

# Check Docker ports
if docker ps --format "{{.Ports}}" | grep -q "80\|443"; then
    print_info "Docker containers are using ports 80/443"
    docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -E "caddy|80|443"
fi
echo ""

# 7. Check Caddyfile
echo "7. Checking Caddyfile..."
if [ -f "Caddyfile" ]; then
    print_info "Caddyfile exists"
    if grep -q "your-domain.com" Caddyfile; then
        print_warn "Caddyfile still contains 'your-domain.com' - update it with your domain!"
    else
        print_info "Caddyfile looks configured"
    fi
else
    print_error "Caddyfile not found!"
fi
echo ""

# 8. Check Logs (recent errors)
echo "8. Checking Recent Logs for Errors..."
echo ""

echo "App service (last 10 lines):"
docker service logs --tail 10 ${STACK_NAME}_app 2>&1 | tail -5
echo ""

echo "Caddy service (last 10 lines):"
docker service logs --tail 10 ${STACK_NAME}_caddy 2>&1 | tail -5
echo ""

# 9. Check Network
echo "9. Checking Network..."
if docker network ls | grep -q "${STACK_NAME}_caddy-network"; then
    print_info "Network exists"
    docker network inspect ${STACK_NAME}_caddy-network --format "{{.Name}}: {{.Driver}}" 2>/dev/null | head -1
else
    print_warn "Network not found"
fi
echo ""

# 10. Check Health
echo "10. Testing Connectivity..."
APP_TASK=$(docker service ps ${STACK_NAME}_app --filter "desired-state=running" --format "{{.ID}}" | head -1)
if [ ! -z "$APP_TASK" ]; then
    print_info "Testing app service on port 8924..."
    # Try to curl from within a container
    if docker run --rm --network ${STACK_NAME}_caddy-network curlimages/curl:latest curl -s -o /dev/null -w "%{http_code}" http://app:8924/ 2>/dev/null | grep -q "200\|301\|302"; then
        print_info "App is responding"
    else
        print_warn "App might not be responding correctly"
    fi
fi
echo ""

# 11. Check Docker Image
echo "11. Checking Docker Image..."
if docker images | grep -q "ios-safari-remote-debug"; then
    print_info "Docker image exists"
    docker images | grep "ios-safari-remote-debug" | head -1
else
    print_error "Docker image 'ios-safari-remote-debug:latest' not found!"
    echo "   Build it with: docker build -t ios-safari-remote-debug:latest ."
fi
echo ""

# 12. Check Environment
echo "12. Checking Environment..."
if [ -f ".env" ]; then
    print_info ".env file exists"
    if grep -q "PROXY_HOST" .env; then
        print_info "PROXY_HOST is configured"
        grep "PROXY_HOST" .env
    fi
else
    print_warn ".env file not found (optional)"
fi
echo ""

# Summary and Recommendations
print_header "Summary & Recommendations"
echo ""

RUNNING_TASKS=$(docker stack ps $STACK_NAME --filter "desired-state=running" --format "{{.CurrentState}}" | grep -c "Running" || echo "0")

if [ "$RUNNING_TASKS" -gt 0 ]; then
    print_info "Stack appears to be running ($RUNNING_TASKS tasks running)"
    echo ""
    echo "Next steps:"
    echo "1. Check logs: ./logs.sh all"
    echo "2. Check status: ./status.sh"
    echo "3. Verify domain points to this server (if using domain)"
    echo "4. Check firewall allows ports 80 and 443"
    echo "5. Try accessing:"
    echo "   - http://localhost (if no domain)"
    echo "   - http://your-domain.com (if domain configured)"
    echo "   - http://$(hostname -I | awk '{print $1}') (server IP)"
else
    print_error "Stack is not running properly!"
    echo ""
    echo "Common issues and fixes:"
    echo ""
    echo "1. Image not found:"
    echo "   docker build -t ios-safari-remote-debug:latest ."
    echo ""
    echo "2. View full logs:"
    echo "   ./logs.sh all"
    echo ""
    echo "3. Check service status:"
    echo "   docker stack ps $STACK_NAME"
    echo ""
    echo "4. Try redeploying:"
    echo "   ./deploy.sh"
    echo ""
    echo "5. Check Docker Swarm:"
    echo "   docker node ls"
fi

echo ""

