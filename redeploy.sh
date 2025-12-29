#!/bin/bash

# Force redeploy script to fix missing services
# Usage: ./redeploy.sh

STACK_NAME="ios-safari-remote-debug"

echo "🔄 Force redeploying stack..."

# Check port conflicts first
echo "🔍 Checking for port conflicts..."
if docker service ls --format "{{.Ports}}" | grep -qE "80|443"; then
    echo "⚠️  Warning: Ports 80/443 are in use by other services"
    docker service ls --format "table {{.Name}}\t{{.Ports}}" | grep -E "80|443"
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Cancelled"
        exit 1
    fi
fi

# Remove stack
echo "🗑️  Removing existing stack..."
docker stack rm $STACK_NAME

# Wait for removal
echo "⏳ Waiting for stack to be removed..."
while docker stack ls | grep -q "$STACK_NAME" 2>/dev/null; do
    sleep 2
done
sleep 3

# Deploy again
echo "🚀 Deploying stack..."
if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

docker stack deploy -c docker-stack.yml $STACK_NAME

sleep 5

# Check services
echo ""
echo "📊 Service status:"
docker stack services $STACK_NAME

echo ""
echo "📋 Task status:"
docker stack ps $STACK_NAME

echo ""
echo "✅ Redeploy complete!"
echo ""
echo "If Caddy service is still missing, check:"
echo "1. Port conflicts: ./fix-ports.sh"
echo "2. Logs: docker stack ps $STACK_NAME --no-trunc"
echo "3. Try using different ports in docker-stack.yml"

