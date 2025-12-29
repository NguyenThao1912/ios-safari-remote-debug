#!/bin/bash

# Scale script for Docker Swarm
# Usage: ./scale.sh [service] [replicas] [stack-name]
#        ./scale.sh app 2
#        ./scale.sh caddy 1

SERVICE="${1}"
REPLICAS="${2}"
STACK_NAME="${3:-ios-safari-remote-debug}"

if [ -z "$SERVICE" ] || [ -z "$REPLICAS" ]; then
    echo "❌ Usage: ./scale.sh [service] [replicas] [stack-name]"
    echo "   Example: ./scale.sh app 2"
    echo "   Example: ./scale.sh caddy 1"
    exit 1
fi

# Validate replicas is a number
if ! [[ "$REPLICAS" =~ ^[0-9]+$ ]]; then
    echo "❌ Replicas must be a number!"
    exit 1
fi

SERVICE_NAME="${STACK_NAME}_${SERVICE}"

# Check if service exists
if ! docker service ls | grep -q "$SERVICE_NAME"; then
    echo "❌ Service $SERVICE_NAME not found!"
    exit 1
fi

echo "📈 Scaling $SERVICE_NAME to $REPLICAS replicas..."

docker service scale ${SERVICE_NAME}=${REPLICAS}

echo "⏳ Waiting for scaling to complete..."
sleep 3

echo "✅ Scaling complete!"
echo ""
echo "📊 Current status:"
docker service ps $SERVICE_NAME

