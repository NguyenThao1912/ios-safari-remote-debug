#!/bin/bash

# Export logs to files for Google Cloud or remote viewing
# Usage: ./export-logs.sh [service] [stack-name]

SERVICE="${1:-all}"
STACK_NAME="${2:-ios-safari-remote-debug}"
OUTPUT_DIR="./logs"

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

# Create logs directory
mkdir -p "$OUTPUT_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

if [ "$SERVICE" = "all" ]; then
    print_info "Exporting all service logs..."
    
    # Export app logs
    if docker service ls | grep -q "${STACK_NAME}_app"; then
        print_info "Exporting app logs..."
        docker service logs --tail 1000 ${STACK_NAME}_app > "${OUTPUT_DIR}/app_${TIMESTAMP}.log" 2>&1
        print_info "App logs saved to: ${OUTPUT_DIR}/app_${TIMESTAMP}.log"
    fi
    
    # Export Caddy logs
    if docker service ls | grep -q "${STACK_NAME}_caddy"; then
        print_info "Exporting Caddy logs..."
        docker service logs --tail 1000 ${STACK_NAME}_caddy > "${OUTPUT_DIR}/caddy_${TIMESTAMP}.log" 2>&1
        print_info "Caddy logs saved to: ${OUTPUT_DIR}/caddy_${TIMESTAMP}.log"
    fi
    
    # Create combined log
    print_info "Creating combined log..."
    {
        echo "=== APP LOGS ==="
        [ -f "${OUTPUT_DIR}/app_${TIMESTAMP}.log" ] && cat "${OUTPUT_DIR}/app_${TIMESTAMP}.log"
        echo ""
        echo "=== CADDY LOGS ==="
        [ -f "${OUTPUT_DIR}/caddy_${TIMESTAMP}.log" ] && cat "${OUTPUT_DIR}/caddy_${TIMESTAMP}.log"
    } > "${OUTPUT_DIR}/combined_${TIMESTAMP}.log"
    
    print_info "Combined logs saved to: ${OUTPUT_DIR}/combined_${TIMESTAMP}.log"
    
elif [ "$SERVICE" = "app" ]; then
    print_info "Exporting app logs..."
    docker service logs --tail 1000 ${STACK_NAME}_app > "${OUTPUT_DIR}/app_${TIMESTAMP}.log" 2>&1
    print_info "Logs saved to: ${OUTPUT_DIR}/app_${TIMESTAMP}.log"
    
elif [ "$SERVICE" = "caddy" ]; then
    print_info "Exporting Caddy logs..."
    docker service logs --tail 1000 ${STACK_NAME}_caddy > "${OUTPUT_DIR}/caddy_${TIMESTAMP}.log" 2>&1
    print_info "Logs saved to: ${OUTPUT_DIR}/caddy_${TIMESTAMP}.log"
    
else
    print_warn "Unknown service: $SERVICE"
    echo "Usage: ./export-logs.sh [app|caddy|all] [stack-name]"
    exit 1
fi

echo ""
print_info "Log files location: $OUTPUT_DIR"
print_info "To view logs: cat ${OUTPUT_DIR}/*.log"
print_info "To download from Google Cloud: gcloud compute scp instance-name:~/path/to/logs/*.log ."

