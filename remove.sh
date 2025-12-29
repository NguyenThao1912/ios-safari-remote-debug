#!/bin/bash

# Remove script for Docker Swarm
# Usage: ./remove.sh [stack-name]

set -e

STACK_NAME="${1:-ios-safari-remote-debug}"

echo "🗑️  Removing stack $STACK_NAME..."

# Check if stack exists
if ! docker stack ls | grep -q "$STACK_NAME"; then
    echo "❌ Stack $STACK_NAME not found!"
    exit 1
fi

# Confirm removal
read -p "Are you sure you want to remove stack $STACK_NAME? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Cancelled"
    exit 1
fi

# Remove stack
docker stack rm $STACK_NAME

echo "⏳ Waiting for stack to be removed..."
while docker stack ls | grep -q "$STACK_NAME"; do
    sleep 2
done

echo "✅ Stack removed successfully!"

# Optionally remove volumes (uncomment if needed)
# read -p "Remove volumes? (y/N): " -n 1 -r
# echo
# if [[ $REPLY =~ ^[Yy]$ ]]; then
#     echo "🗑️  Removing volumes..."
#     docker volume rm ${STACK_NAME}_app_dist ${STACK_NAME}_caddy_data ${STACK_NAME}_caddy_config ${STACK_NAME}_caddy_logs 2>/dev/null || true
#     echo "✅ Volumes removed"
# fi

