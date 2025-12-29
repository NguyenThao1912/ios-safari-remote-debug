#!/bin/bash

# Setup script for Google Cloud Platform
# This script installs all dependencies and sets up the environment
# Usage: ./setup-gcp.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_header "GCP Setup Script"

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_warn "Running as root. Some commands may need adjustment."
fi

# 1. Update system
print_header "1. Updating System"
print_info "Updating package list..."
sudo apt update
sudo apt upgrade -y
print_info "System updated"

# 2. Install Git
print_header "2. Installing Git"
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version)
    print_info "Git already installed: $GIT_VERSION"
else
    print_info "Installing Git..."
    sudo apt install git -y
    print_info "Git installed: $(git --version)"
fi

# 3. Install Docker
print_header "3. Installing Docker"
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    print_info "Docker already installed: $DOCKER_VERSION"
else
    print_info "Installing Docker..."
    
    # Remove old versions
    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Install dependencies
    sudo apt install -y ca-certificates curl gnupg lsb-release
    
    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Setup repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    print_info "Docker installed: $(docker --version)"
fi

# 4. Add user to docker group
print_header "4. Configuring Docker Permissions"
CURRENT_USER=${SUDO_USER:-$USER}
if [ "$CURRENT_USER" != "root" ]; then
    if groups $CURRENT_USER | grep -q docker; then
        print_info "User $CURRENT_USER already in docker group"
    else
        print_info "Adding user $CURRENT_USER to docker group..."
        sudo usermod -aG docker $CURRENT_USER
        print_warn "User added to docker group. You may need to logout/login or run: newgrp docker"
    fi
else
    print_warn "Running as root, skipping user group configuration"
fi

# 5. Start Docker service
print_header "5. Starting Docker Service"
if sudo systemctl is-active --quiet docker; then
    print_info "Docker service is running"
else
    print_info "Starting Docker service..."
    sudo systemctl start docker
    sudo systemctl enable docker
    print_info "Docker service started"
fi

# 6. Install Go (if needed for building)
print_header "6. Installing Go"
if command -v go &> /dev/null; then
    GO_VERSION=$(go version)
    print_info "Go already installed: $GO_VERSION"
    
    # Check version
    GO_VER=$(go version | awk '{print $3}' | sed 's/go//')
    REQUIRED_VER="1.21.6"
    if [ "$(printf '%s\n' "$REQUIRED_VER" "$GO_VER" | sort -V | head -n1)" != "$REQUIRED_VER" ]; then
        print_warn "Go version $GO_VER is older than required $REQUIRED_VER"
        print_info "Installing newer Go version..."
        # Install Go 1.21.6 or newer
        GO_VERSION="1.21.6"
        wget -q https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz
        sudo rm -rf /usr/local/go
        sudo tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
        rm go${GO_VERSION}.linux-amd64.tar.gz
        print_info "Go updated to $(/usr/local/go/bin/go version)"
    fi
else
    print_info "Installing Go..."
    GO_VERSION="1.21.6"
    wget -q https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz
    sudo tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
    rm go${GO_VERSION}.linux-amd64.tar.gz
    
    # Add to PATH
    if ! grep -q "/usr/local/go/bin" ~/.bashrc; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
        export PATH=$PATH:/usr/local/go/bin
    fi
    
    print_info "Go installed: $(/usr/local/go/bin/go version)"
fi

# 7. Make all scripts executable
print_header "7. Setting Script Permissions"
print_info "Making all scripts executable..."
chmod +x *.sh 2>/dev/null || true
print_info "Scripts are now executable"

# 8. Initialize Docker Swarm
print_header "8. Initializing Docker Swarm"
if docker info 2>/dev/null | grep -q "Swarm: active"; then
    print_info "Docker Swarm is already active"
else
    print_info "Initializing Docker Swarm..."
    # Get internal IP for GCP
    INTERNAL_IP=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip -H "Metadata-Flavor: Google" 2>/dev/null || hostname -I | awk '{print $1}')
    
    if [ ! -z "$INTERNAL_IP" ]; then
        docker swarm init --advertise-addr "$INTERNAL_IP"
    else
        docker swarm init
    fi
    print_info "Docker Swarm initialized"
fi

# 9. Check firewall (GCP specific)
print_header "9. Checking Firewall"
print_info "Checking if ports 80, 443, 8080, 8443 are accessible..."
print_warn "Make sure to open these ports in GCP Firewall Rules:"
echo "  - Port 80 (HTTP)"
echo "  - Port 443 (HTTPS)"
echo "  - Port 8080 (HTTP alt)"
echo "  - Port 8443 (HTTPS alt)"
echo ""
print_info "To open ports in GCP:"
echo "  gcloud compute firewall-rules create allow-http --allow tcp:80,tcp:443,tcp:8080,tcp:8443 --source-ranges 0.0.0.0/0"

# 10. Build Docker image
print_header "10. Building Docker Image"
if [ -f "Dockerfile" ]; then
    print_info "Building Docker image..."
    docker build -t ios-safari-remote-debug:latest .
    print_info "Docker image built successfully"
else
    print_warn "Dockerfile not found. Skipping image build."
fi

# 11. Check Caddyfile
print_header "11. Checking Caddyfile"
if [ -f "Caddyfile" ]; then
    if grep -q "your-domain.com" Caddyfile; then
        print_warn "Caddyfile still contains 'your-domain.com'"
        print_info "You should update it with your domain or 'localhost'"
        print_info "Edit Caddyfile: nano Caddyfile"
    else
        print_info "Caddyfile looks configured"
    fi
else
    print_warn "Caddyfile not found!"
fi

# Summary
print_header "Setup Complete!"
echo ""
print_info "Next steps:"
echo "1. If user was added to docker group, logout and login again"
echo "2. Or run: newgrp docker"
echo "3. Update Caddyfile if needed: nano Caddyfile"
echo "4. Deploy stack: ./deploy.sh"
echo "5. Or use menu: ./run.sh"
echo ""
print_info "To verify setup:"
echo "  docker --version"
echo "  docker compose version"
echo "  docker info | grep Swarm"
echo "  go version"
echo ""

