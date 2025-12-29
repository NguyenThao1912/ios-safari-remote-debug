#!/bin/bash

# View logs script with better formatting for Google Cloud
# Usage: ./view-logs.sh [service] [stack-name]

SERVICE="${1:-all}"
STACK_NAME="${2:-ios-safari-remote-debug}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

print_header "View Logs - Google Cloud Compatible"

# Check if stack exists
if ! docker stack ls | grep -q "$STACK_NAME"; then
    print_error "Stack $STACK_NAME not found!"
    exit 1
fi

echo ""
echo "Options:"
echo "1) View live logs (follow)"
echo "2) View last 100 lines (no follow)"
echo "3) View last 500 lines (no follow)"
echo "4) Export logs to files"
echo "5) View specific service"
echo ""
read -p "Choice [1-5]: " choice

case $choice in
    1)
        print_info "Showing live logs (Ctrl+C to exit)..."
        echo ""
        if [ "$SERVICE" = "all" ]; then
            docker service logs -f ${STACK_NAME}_app ${STACK_NAME}_caddy 2>&1
        elif [ "$SERVICE" = "app" ]; then
            docker service logs -f ${STACK_NAME}_app 2>&1
        elif [ "$SERVICE" = "caddy" ]; then
            docker service logs -f ${STACK_NAME}_caddy 2>&1
        else
            docker service logs -f ${STACK_NAME}_${SERVICE} 2>&1
        fi
        ;;
    2)
        print_info "Last 100 lines:"
        echo ""
        if [ "$SERVICE" = "all" ]; then
            echo "=== APP LOGS ==="
            docker service logs --tail 100 --no-trunc ${STACK_NAME}_app 2>&1
            echo ""
            echo "=== CADDY LOGS ==="
            docker service logs --tail 100 --no-trunc ${STACK_NAME}_caddy 2>&1
        elif [ "$SERVICE" = "app" ]; then
            docker service logs --tail 100 --no-trunc ${STACK_NAME}_app 2>&1
        elif [ "$SERVICE" = "caddy" ]; then
            docker service logs --tail 100 --no-trunc ${STACK_NAME}_caddy 2>&1
        else
            docker service logs --tail 100 --no-trunc ${STACK_NAME}_${SERVICE} 2>&1
        fi
        ;;
    3)
        print_info "Last 500 lines:"
        echo ""
        if [ "$SERVICE" = "all" ]; then
            echo "=== APP LOGS ==="
            docker service logs --tail 500 --no-trunc ${STACK_NAME}_app 2>&1
            echo ""
            echo "=== CADDY LOGS ==="
            docker service logs --tail 500 --no-trunc ${STACK_NAME}_caddy 2>&1
        elif [ "$SERVICE" = "app" ]; then
            docker service logs --tail 500 --no-trunc ${STACK_NAME}_app 2>&1
        elif [ "$SERVICE" = "caddy" ]; then
            docker service logs --tail 500 --no-trunc ${STACK_NAME}_caddy 2>&1
        else
            docker service logs --tail 500 --no-trunc ${STACK_NAME}_${SERVICE} 2>&1
        fi
        ;;
    4)
        ./export-logs.sh "$SERVICE" "$STACK_NAME"
        ;;
    5)
        echo ""
        echo "Select service:"
        echo "1) App"
        echo "2) Caddy"
        read -p "Choice [1-2]: " svc_choice
        case $svc_choice in
            1)
                ./view-logs.sh app "$STACK_NAME"
                ;;
            2)
                ./view-logs.sh caddy "$STACK_NAME"
                ;;
            *)
                print_error "Invalid choice"
                ;;
        esac
        ;;
    *)
        print_error "Invalid choice"
        exit 1
        ;;
esac

