#!/bin/bash

# List all Docker Swarm stacks with details
# Usage: ./list-stacks.sh

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Docker Swarm Stacks${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if Docker Swarm is active
if ! docker info | grep -q "Swarm: active"; then
    echo "Docker Swarm is not active!"
    exit 1
fi

# List stacks
echo "Stacks:"
docker stack ls
echo ""

# Show services for each stack
STACKS=$(docker stack ls --format "{{.Name}}")

if [ -z "$STACKS" ]; then
    echo "No stacks found"
    exit 0
fi

for stack in $STACKS; do
    echo -e "${BLUE}--- Stack: $stack ---${NC}"
    
    # Show services
    echo "Services:"
    docker stack services $stack 2>/dev/null || echo "  (no services)"
    
    # Show ports in use
    echo "Ports in use:"
    docker service ls --filter "label=com.docker.stack.namespace=$stack" --format "{{.Ports}}" 2>/dev/null | grep -oE "[0-9]+->[0-9]+" | sort -u || echo "  (none)"
    
    echo ""
done

