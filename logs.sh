#!/bin/bash

# Logs script for Docker Swarm
# Usage: ./logs.sh [service] [stack-name]
#        ./logs.sh app
#        ./logs.sh caddy
#        ./logs.sh all

SERVICE="${1:-all}"
STACK_NAME="${2:-ios-safari-remote-debug}"

if [ "$SERVICE" = "all" ]; then
    echo "📋 Showing logs for all services (Ctrl+C to exit)..."
    echo ""
    docker service logs -f ${STACK_NAME}_app ${STACK_NAME}_caddy
elif [ "$SERVICE" = "app" ]; then
    echo "📋 Showing app logs (Ctrl+C to exit)..."
    echo ""
    docker service logs -f ${STACK_NAME}_app
elif [ "$SERVICE" = "caddy" ]; then
    echo "📋 Showing Caddy logs (Ctrl+C to exit)..."
    echo ""
    docker service logs -f ${STACK_NAME}_caddy
else
    echo "❌ Unknown service: $SERVICE"
    echo "Usage: ./logs.sh [app|caddy|all] [stack-name]"
    exit 1
fi

