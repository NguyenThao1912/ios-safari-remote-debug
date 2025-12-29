#!/bin/bash

# Stop all other Docker Swarm stacks
# Usage: ./stop-other-stacks.sh [--force]

STACK_NAME="ios-safari-remote-debug"
FORCE="${1}"

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

print_header "Stop Other Docker Swarm Stacks"

# Check if Docker Swarm is active
if ! docker info | grep -q "Swarm: active"; then
    print_error "Docker Swarm is not active!"
    exit 1
fi

# List all stacks
echo ""
print_info "Current stacks:"
docker stack ls
echo ""

# Get all stacks except the current one
OTHER_STACKS=$(docker stack ls --format "{{.Name}}" | grep -v "^${STACK_NAME}$" || true)

if [ -z "$OTHER_STACKS" ]; then
    print_info "No other stacks found. Only $STACK_NAME is running."
    exit 0
fi

echo "Stacks to stop:"
echo "$OTHER_STACKS" | while read stack; do
    if [ ! -z "$stack" ]; then
        echo "  - $stack"
    fi
done
echo ""

# Confirm
if [ "$FORCE" != "--force" ]; then
    print_warn "This will stop all stacks except: $STACK_NAME"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Cancelled"
        exit 0
    fi
fi

# Stop each stack
echo ""
print_info "Stopping stacks..."
echo ""

echo "$OTHER_STACKS" | while read stack; do
    if [ ! -z "$stack" ]; then
        print_info "Stopping stack: $stack"
        docker stack rm "$stack" 2>&1 | grep -v "Nothing found" || true
        
        # Wait for stack to be removed
        while docker stack ls --format "{{.Name}}" | grep -q "^${stack}$" 2>/dev/null; do
            sleep 2
        done
        
        print_info "✓ Stack $stack stopped"
    fi
done

echo ""
print_info "All other stacks have been stopped!"
echo ""
print_info "Current stacks:"
docker stack ls
echo ""
print_info "You can now deploy $STACK_NAME with ports 80/443 available"

