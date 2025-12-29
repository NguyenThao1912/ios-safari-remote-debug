#!/bin/bash

# Quick fix script for common access issues
# Usage: ./quick-fix.sh

STACK_NAME="ios-safari-remote-debug"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_header "Quick Fix for Access Issues"

# 1. Fix Caddyfile
echo "1. Checking Caddyfile..."
if [ -f "Caddyfile" ]; then
    if grep -q "your-domain.com" Caddyfile; then
        print_warn "Caddyfile needs to be updated"
        echo ""
        echo "Options:"
        echo "  A) Use localhost (for testing)"
        echo "  B) Use your domain"
        echo "  C) Skip for now"
        echo ""
        read -p "Choice [A/B/C]: " choice
        
        case $choice in
            A|a)
                # Backup original
                cp Caddyfile Caddyfile.backup
                # Replace with localhost
                sed -i.bak 's/your-domain\.com/localhost/g' Caddyfile
                print_info "Caddyfile updated to use localhost"
                ;;
            B|b)
                read -p "Enter your domain: " domain
                if [ ! -z "$domain" ]; then
                    cp Caddyfile Caddyfile.backup
                    sed -i.bak "s/your-domain\.com/$domain/g" Caddyfile
                    print_info "Caddyfile updated to use $domain"
                fi
                ;;
            *)
                print_warn "Skipping Caddyfile update"
                ;;
        esac
    else
        print_info "Caddyfile looks good"
    fi
else
    print_error "Caddyfile not found!"
    exit 1
fi
echo ""

# 2. Check and fix stack
echo "2. Checking stack status..."
if docker stack ls | grep -q "$STACK_NAME"; then
    print_info "Stack exists"
    
    # Check if services are running
    APP_SERVICE="${STACK_NAME}_app"
    CADDY_SERVICE="${STACK_NAME}_caddy"
    
    if ! docker service ls | grep -q "$APP_SERVICE"; then
        print_warn "App service not found, redeploying..."
    fi
    
    if ! docker service ls | grep -q "$CADDY_SERVICE"; then
        print_warn "Caddy service not found, redeploying..."
    fi
    
    # Check for port conflicts
    if docker service ls --format "{{.Ports}}" | grep -qE "80|443"; then
        print_warn "Ports 80/443 might be in use"
        echo "   Checking port conflicts..."
        docker service ls --format "table {{.Name}}\t{{.Ports}}" | grep -E "80|443"
        echo ""
        read -p "Use alternative ports (8080/8443)? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Redeploying with alternative ports..."
            docker stack rm $STACK_NAME
            sleep 5
            docker stack deploy -c docker-stack-alt-ports.yml $STACK_NAME
            print_info "Deployed with ports 8080/8443"
            echo "   Access at: http://localhost:8080"
            exit 0
        fi
    fi
    
    print_info "Redeploying stack..."
    ./redeploy.sh
else
    print_warn "Stack not found, deploying..."
    ./deploy.sh
fi
echo ""

# 3. Wait and test
echo "3. Waiting for services to start..."
sleep 10

echo ""
print_info "Running access test..."
./test-access.sh

