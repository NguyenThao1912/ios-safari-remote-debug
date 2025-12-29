#!/bin/bash

# Logs script for Docker Swarm
# Usage: ./logs.sh [service] [stack-name] [--tail N] [--no-follow]
#        ./logs.sh app
#        ./logs.sh caddy
#        ./logs.sh all
#        ./logs.sh app --tail 100
#        ./logs.sh all --no-follow

SERVICE="${1:-all}"
STACK_NAME="${2:-ios-safari-remote-debug}"
TAIL_LINES=""
NO_FOLLOW=""

# Parse arguments
shift 2 2>/dev/null || shift 1 2>/dev/null || true
while [[ $# -gt 0 ]]; do
    case $1 in
        --tail)
            TAIL_LINES="$2"
            shift 2
            ;;
        --no-follow)
            NO_FOLLOW="--no-trunc"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Build docker command
DOCKER_CMD="docker service logs"
if [ ! -z "$TAIL_LINES" ]; then
    DOCKER_CMD="$DOCKER_CMD --tail $TAIL_LINES"
fi
if [ -z "$NO_FOLLOW" ]; then
    DOCKER_CMD="$DOCKER_CMD -f"
else
    DOCKER_CMD="$DOCKER_CMD $NO_FOLLOW"
fi

if [ "$SERVICE" = "all" ]; then
    echo "📋 Showing logs for all services..."
    if [ -z "$NO_FOLLOW" ]; then
        echo "   (Ctrl+C to exit)"
    fi
    echo ""
    $DOCKER_CMD ${STACK_NAME}_app ${STACK_NAME}_caddy 2>&1
elif [ "$SERVICE" = "app" ]; then
    echo "📋 Showing app logs..."
    if [ -z "$NO_FOLLOW" ]; then
        echo "   (Ctrl+C to exit)"
    fi
    echo ""
    $DOCKER_CMD ${STACK_NAME}_app 2>&1
elif [ "$SERVICE" = "caddy" ]; then
    echo "📋 Showing Caddy logs..."
    if [ -z "$NO_FOLLOW" ]; then
        echo "   (Ctrl+C to exit)"
    fi
    echo ""
    $DOCKER_CMD ${STACK_NAME}_caddy 2>&1
else
    echo "❌ Unknown service: $SERVICE"
    echo "Usage: ./logs.sh [app|caddy|all] [stack-name] [--tail N] [--no-follow]"
    exit 1
fi

