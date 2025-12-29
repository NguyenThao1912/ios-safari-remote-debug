#!/bin/bash

# Initialize Docker Swarm script
# Usage: ./init-swarm.sh [advertise-addr]

set -e

ADVERTISE_ADDR="${1}"

echo "🔧 Initializing Docker Swarm..."

# Check if already in swarm mode
if docker info | grep -q "Swarm: active"; then
    echo "⚠️  Docker Swarm is already initialized!"
    echo ""
    echo "Current swarm info:"
    docker info | grep -A 5 "Swarm:"
    echo ""
    read -p "Do you want to leave the current swarm? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker swarm leave --force
        echo "✅ Left swarm"
    else
        echo "❌ Cancelled"
        exit 1
    fi
fi

# Initialize swarm
if [ -z "$ADVERTISE_ADDR" ]; then
    echo "🚀 Initializing Docker Swarm (auto-detect address)..."
    docker swarm init
else
    echo "🚀 Initializing Docker Swarm (advertise-addr: $ADVERTISE_ADDR)..."
    docker swarm init --advertise-addr "$ADVERTISE_ADDR"
fi

echo ""
echo "✅ Docker Swarm initialized!"
echo ""
echo "📋 Join token for workers:"
docker swarm join-token worker
echo ""
echo "📋 Join token for managers:"
docker swarm join-token manager
echo ""
echo "💡 To add nodes, run the join command on other machines"
echo "💡 To deploy: ./deploy.sh"

