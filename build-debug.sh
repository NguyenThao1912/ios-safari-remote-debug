#!/bin/bash

# Debug build script to test Docker build locally
# Usage: ./build-debug.sh

set -e

echo "🔍 Debugging Docker build..."
echo ""

# Check if Dockerfile exists
if [ ! -f "Dockerfile" ]; then
    echo "❌ Dockerfile not found!"
    exit 1
fi

# Check if go.mod exists
if [ ! -f "go.mod" ]; then
    echo "❌ go.mod not found!"
    exit 1
fi

# Test Go build locally first
echo "1. Testing Go build locally..."
if go build -o ios-safari-remote-debug . 2>&1; then
    echo "✅ Local build successful"
    rm -f ios-safari-remote-debug
else
    echo "❌ Local build failed! Fix errors first."
    exit 1
fi
echo ""

# Test Docker build with no cache
echo "2. Building Docker image (no cache)..."
if docker build --no-cache --progress=plain -t ios-safari-remote-debug:latest . 2>&1 | tee build.log; then
    echo "✅ Docker build successful"
else
    echo "❌ Docker build failed!"
    echo ""
    echo "Last 50 lines of build output:"
    tail -50 build.log
    echo ""
    echo "Check build.log for full details"
    exit 1
fi

echo ""
echo "✅ All builds successful!"

