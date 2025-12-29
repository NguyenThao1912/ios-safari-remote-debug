#!/bin/bash

# Stop stack script (quick stop without removal)
# Usage: ./stop.sh [stack-name]

STACK_NAME="${1:-ios-safari-remote-debug}"

# Colors
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

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_header "Stop Stack"

# Check if stack exists
if ! docker stack ls | grep -q "$STACK_NAME"; then
    print_warn "Stack $STACK_NAME not found!"
    exit 1
fi

echo ""
print_info "Stopping all services in stack: $STACK_NAME"
echo ""

# Scale down all services to 0
SERVICES=$(docker stack services $STACK_NAME --format "{{.Name}}")

if [ -z "$SERVICES" ]; then
    print_warn "No services found in stack"
    exit 1
fi

for service in $SERVICES; do
    print_info "Scaling down: $service"
    docker service scale ${service}=0 2>/dev/null || true
done

echo ""
print_info "Stack services stopped (scaled to 0)"
echo ""
print_info "To start again:"
echo "  ./deploy.sh"
echo ""
print_info "To completely remove stack:"
echo "  ./remove.sh"

