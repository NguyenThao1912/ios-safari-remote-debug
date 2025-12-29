#!/bin/bash

# Fix port conflict script
# Usage: ./fix-ports.sh

STACK_NAME="ios-safari-remote-debug"

echo "🔍 Checking port conflicts..."

# Check if ports 80/443 are in use
if netstat -tuln 2>/dev/null | grep -q ":80 "; then
    echo "⚠️  Port 80 is in use"
    netstat -tuln | grep ":80 "
fi

if netstat -tuln 2>/dev/null | grep -q ":443 "; then
    echo "⚠️  Port 443 is in use"
    netstat -tuln | grep ":443 "
fi

# Check Docker services using ports
echo ""
echo "📋 Docker services using ports 80/443:"
docker service ls --format "table {{.Name}}\t{{.Ports}}" | grep -E "80|443" || echo "None found"

echo ""
echo "💡 Solutions:"
echo ""
echo "Option 1: Use different ports (8080, 8443)"
echo "   docker stack deploy -c docker-stack-alt-ports.yml ios-safari-remote-debug"
echo "   Then access via: http://your-domain.com:8080"
echo ""
echo "Option 2: Stop conflicting service"
echo "   docker service scale book_stack_caddy=0"
echo "   Then redeploy: ./redeploy.sh"
echo ""
echo "Option 3: Use existing Caddy (if possible)"
echo "   Configure existing Caddy to proxy to this app"
echo ""
echo "Option 4: Remove conflicting stack (if not needed)"
echo "   docker stack rm book_stack"
echo "   Then redeploy: ./redeploy.sh"
echo ""

