#!/bin/bash

# Update script for Docker Swarm
# Usage: ./update.sh [stack-name]

set -e

STACK_NAME="${1:-ios-safari-remote-debug}"
IMAGE_NAME="ios-safari-remote-debug:latest"

echo "🔄 Updating $STACK_NAME..."

# Check if stack exists
if ! docker stack ls | grep -q "$STACK_NAME"; then
    echo "❌ Stack $STACK_NAME not found!"
    echo "Deploy it first with: ./deploy.sh"
    exit 1
fi

# Build new image
if [ -f "Dockerfile" ]; then
    echo "📦 Building new Docker image..."
    docker build -t $IMAGE_NAME .
fi

# Update stack
echo "🔄 Updating stack..."
docker stack deploy -c docker-stack.yml $STACK_NAME

# Wait for update
echo "⏳ Waiting for services to update..."
sleep 5

# Show service status
echo ""
echo "✅ Update complete!"
echo ""
echo "📊 Service status:"
docker stack services $STACK_NAME

echo ""
echo "📋 Watch update progress:"
echo "   watch -n 1 'docker stack ps $STACK_NAME'"

