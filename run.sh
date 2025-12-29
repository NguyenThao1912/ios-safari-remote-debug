#!/bin/bash

# Interactive menu script for Docker Swarm management
# Usage: ./run.sh

STACK_NAME="ios-safari-remote-debug"
IMAGE_NAME="ios-safari-remote-debug:latest"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored message
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

# Check if Docker Swarm is active
check_swarm() {
    if ! docker info | grep -q "Swarm: active"; then
        print_warn "Docker Swarm is not initialized!"
        echo ""
        read -p "Do you want to initialize Docker Swarm now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ./init-swarm.sh
        else
            return 1
        fi
    fi
    return 0
}

# Check if stack exists
check_stack() {
    if ! docker stack ls | grep -q "$STACK_NAME"; then
        print_error "Stack $STACK_NAME not found!"
        return 1
    fi
    return 0
}

# Deploy stack
deploy_stack() {
    print_header "Deploying Stack"
    
    if ! check_swarm; then
        return 1
    fi
    
    if check_stack; then
        print_warn "Stack $STACK_NAME already exists!"
        read -p "Do you want to update it instead? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            update_stack
            return 0
        else
            return 1
        fi
    fi
    
    # Check Caddyfile
    if [ ! -f "Caddyfile" ]; then
        print_error "Caddyfile not found!"
        print_info "Please create Caddyfile with your domain configuration"
        return 1
    fi
    
    # Build image
    if [ -f "Dockerfile" ]; then
        print_info "Building Docker image..."
        docker build -t $IMAGE_NAME . || {
            print_error "Build failed!"
            return 1
        }
    fi
    
    # Load environment
    if [ -f ".env" ]; then
        print_info "Loading environment variables from .env"
        export $(cat .env | grep -v '^#' | xargs)
    fi
    
    # Deploy
    print_info "Deploying stack..."
    docker stack deploy -c docker-stack.yml $STACK_NAME
    
    sleep 3
    
    print_info "Deployment complete!"
    show_status
}

# Update stack
update_stack() {
    print_header "Updating Stack"
    
    if ! check_stack; then
        print_error "Stack not found. Deploy it first!"
        return 1
    fi
    
    # Build new image
    if [ -f "Dockerfile" ]; then
        print_info "Building new Docker image..."
        docker build -t $IMAGE_NAME . || {
            print_error "Build failed!"
            return 1
        }
    fi
    
    # Load environment
    if [ -f ".env" ]; then
        print_info "Loading environment variables from .env"
        export $(cat .env | grep -v '^#' | xargs)
    fi
    
    # Update
    print_info "Updating stack..."
    docker stack deploy -c docker-stack.yml $STACK_NAME
    
    sleep 3
    
    print_info "Update complete!"
    show_status
}

# Remove stack
remove_stack() {
    print_header "Removing Stack"
    
    if ! check_stack; then
        print_error "Stack not found!"
        return 1
    fi
    
    print_warn "This will remove the entire stack: $STACK_NAME"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Cancelled"
        return 0
    fi
    
    docker stack rm $STACK_NAME
    
    print_info "Waiting for stack to be removed..."
    while docker stack ls | grep -q "$STACK_NAME" 2>/dev/null; do
        sleep 2
    done
    
    print_info "Stack removed successfully!"
}

# Show status
show_status() {
    print_header "Stack Status"
    
    if ! check_stack; then
        return 1
    fi
    
    echo ""
    print_info "Services:"
    docker stack services $STACK_NAME
    echo ""
    
    print_info "Tasks:"
    docker stack ps $STACK_NAME
    echo ""
}

# Show logs
show_logs() {
    print_header "Service Logs"
    
    if ! check_stack; then
        return 1
    fi
    
    echo ""
    echo "Select service to view logs:"
    echo "1) App"
    echo "2) Caddy"
    echo "3) All"
    echo "4) Back"
    echo ""
    read -p "Choice [1-4]: " choice
    
    case $choice in
        1)
            print_info "Showing app logs (Ctrl+C to exit)..."
            docker service logs -f ${STACK_NAME}_app
            ;;
        2)
            print_info "Showing Caddy logs (Ctrl+C to exit)..."
            docker service logs -f ${STACK_NAME}_caddy
            ;;
        3)
            print_info "Showing all logs (Ctrl+C to exit)..."
            docker service logs -f ${STACK_NAME}_app ${STACK_NAME}_caddy
            ;;
        4)
            return 0
            ;;
        *)
            print_error "Invalid choice!"
            ;;
    esac
}

# Scale service
scale_service() {
    print_header "Scale Service"
    
    if ! check_stack; then
        return 1
    fi
    
    echo ""
    echo "Select service to scale:"
    echo "1) App"
    echo "2) Caddy"
    echo "3) Back"
    echo ""
    read -p "Choice [1-3]: " service_choice
    
    case $service_choice in
        1)
            SERVICE="app"
            ;;
        2)
            SERVICE="caddy"
            ;;
        3)
            return 0
            ;;
        *)
            print_error "Invalid choice!"
            return 1
            ;;
    esac
    
    echo ""
    read -p "Enter number of replicas: " replicas
    
    if ! [[ "$replicas" =~ ^[0-9]+$ ]]; then
        print_error "Replicas must be a number!"
        return 1
    fi
    
    SERVICE_NAME="${STACK_NAME}_${SERVICE}"
    
    print_info "Scaling $SERVICE_NAME to $replicas replicas..."
    docker service scale ${SERVICE_NAME}=${replicas}
    
    sleep 3
    
    print_info "Scaling complete!"
    docker service ps $SERVICE_NAME
}

# Initialize Swarm
init_swarm() {
    print_header "Initialize Docker Swarm"
    
    if docker info | grep -q "Swarm: active"; then
        print_warn "Docker Swarm is already initialized!"
        docker info | grep -A 5 "Swarm:"
        echo ""
        read -p "Do you want to leave and reinitialize? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 0
        fi
        docker swarm leave --force 2>/dev/null || true
    fi
    
    read -p "Enter advertise address (leave empty for auto-detect): " addr
    
    if [ -z "$addr" ]; then
        ./init-swarm.sh
    else
        ./init-swarm.sh "$addr"
    fi
}

# Main menu
show_menu() {
    clear
    print_header "Docker Swarm Management"
    echo ""
    echo "Stack: $STACK_NAME"
    echo ""
    
    # Check swarm status
    if docker info | grep -q "Swarm: active" 2>/dev/null; then
        print_info "Swarm: Active"
    else
        print_warn "Swarm: Not initialized"
    fi
    
    # Check stack status
    if docker stack ls | grep -q "$STACK_NAME" 2>/dev/null; then
        print_info "Stack: Deployed"
    else
        print_warn "Stack: Not deployed"
    fi
    
    echo ""
    echo "Select an option:"
    echo ""
    echo "1) Deploy stack"
    echo "2) Update stack"
    echo "3) Remove stack"
    echo "4) Show status"
    echo "5) View logs"
    echo "6) Scale service"
    echo "7) Initialize Swarm"
    echo "8) Troubleshoot (check.sh)"
    echo "9) Force redeploy (fix missing services)"
    echo "10) List all stacks"
    echo "11) Stop other stacks"
    echo "12) Test access"
    echo "13) Quick fix (auto-fix common issues)"
    echo "14) Stop stack (scale to 0)"
    echo "15) View logs (Google Cloud compatible)"
    echo "16) Export logs to files"
    echo "17) Exit"
    echo ""
}

# Main loop
main() {
    while true; do
        show_menu
        read -p "Choice [1-17]: " choice
        echo ""
        
        case $choice in
            1)
                deploy_stack
                ;;
            2)
                update_stack
                ;;
            3)
                remove_stack
                ;;
            4)
                show_status
                ;;
            5)
                show_logs
                ;;
            6)
                scale_service
                ;;
            7)
                init_swarm
                ;;
            8)
                ./check.sh
                ;;
            9)
                ./redeploy.sh
                ;;
            10)
                ./list-stacks.sh
                ;;
            11)
                ./stop-other-stacks.sh
                ;;
            12)
                ./test-access.sh
                ;;
            13)
                ./quick-fix.sh
                ;;
            14)
                ./stop.sh
                ;;
            15)
                ./view-logs.sh
                ;;
            16)
                ./export-logs.sh
                ;;
            17)
                print_info "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid choice!"
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Run main function
main

