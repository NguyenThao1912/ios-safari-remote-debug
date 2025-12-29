#!/bin/bash

# Deploy script for Docker Swarm
# Usage: ./deploy.sh [stack-name]

set -e

STACK_NAME="${1:-ios-safari-remote-debug}"
IMAGE_NAME="ios-safari-remote-debug:latest"

echo "🚀 Deploying $STACK_NAME to Docker Swarm..."

# Check if Docker Swarm is initialized
if ! docker info | grep -q "Swarm: active"; then
    echo "❌ Docker Swarm is not initialized!"
    echo "Initialize it with: docker swarm init"
    exit 1
fi

# Check if Caddyfile exists
if [ ! -f "Caddyfile" ]; then
    echo "❌ Caddyfile not found!"
    echo "Please create Caddyfile with your domain configuration"
    exit 1
fi

# Build image if Dockerfile exists
if [ -f "Dockerfile" ]; then
    echo "📦 Building Docker image..."
    docker build -t $IMAGE_NAME .
    
    # Save image to file for distribution to other nodes (optional)
    # docker save $IMAGE_NAME | gzip > ios-safari-remote-debug.tar.gz
    # echo "💾 Image saved. Load on other nodes with: docker load < ios-safari-remote-debug.tar.gz"
fi

# Load environment variables if .env exists
if [ -f ".env" ]; then
    echo "📝 Loading environment variables from .env"
    export $(cat .env | grep -v '^#' | xargs)
fi

# Deploy stack
echo "🚀 Deploying stack..."
if docker stack deploy -c docker-stack.yml $STACK_NAME; then
    echo "✅ Stack deployed successfully"
else
    echo "❌ Stack deployment failed!"
    echo ""
    echo "Common issues:"
    echo "1. Port conflict - ports 80/443 might be in use"
    echo "   Run: ./fix-ports.sh"
    echo "2. Image not found - build image first"
    echo "   Run: docker build -t $IMAGE_NAME ."
    exit 1
fi

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 5

# Show service status
echo ""
echo "✅ Deployment complete!"
echo ""
echo "📊 Service status:"
docker stack services $STACK_NAME

echo ""
echo "📋 Service logs (Ctrl+C to exit):"
echo "   docker service logs -f ${STACK_NAME}_app"
echo "   docker service logs -f ${STACK_NAME}_caddy"
echo ""
echo "🔍 Check status:"
echo "   docker stack ps $STACK_NAME"
echo ""
echo "🛑 To remove stack:"
echo "   docker stack rm $STACK_NAME"

