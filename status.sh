#!/bin/bash

# Status script for Docker Swarm
# Usage: ./status.sh [stack-name]

STACK_NAME="${1:-ios-safari-remote-debug}"

echo "📊 Stack: $STACK_NAME"
echo ""

# Check if stack exists
if ! docker stack ls | grep -q "$STACK_NAME"; then
    echo "❌ Stack $STACK_NAME not found!"
    exit 1
fi

echo "📋 Services:"
docker stack services $STACK_NAME
echo ""

echo "🔄 Tasks:"
docker stack ps $STACK_NAME
echo ""

echo "📊 Service details:"
echo ""
echo "App service:"
docker service ps ${STACK_NAME}_app --no-trunc
echo ""

echo "Caddy service:"
docker service ps ${STACK_NAME}_caddy --no-trunc
echo ""

echo "💾 Volumes:"
docker volume ls | grep "$STACK_NAME" || echo "No volumes found"
echo ""

echo "🌐 Networks:"
docker network ls | grep "$STACK_NAME" || echo "No networks found"

