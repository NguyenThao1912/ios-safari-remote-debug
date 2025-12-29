#!/bin/bash

# Installation script for ios-safari-remote-debug build requirements
# This script installs Go, Git, and optionally ios_webkit_debug_proxy

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check Go version
check_go_version() {
    if command_exists go; then
        GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
        REQUIRED_VERSION="1.21.6"
        
        # Simple version comparison
        if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$GO_VERSION" | sort -V | head -n1)" = "$REQUIRED_VERSION" ]; then
            print_info "Go version $GO_VERSION is installed and meets requirement ($REQUIRED_VERSION+)"
            return 0
        else
            print_warn "Go version $GO_VERSION is installed but does not meet requirement ($REQUIRED_VERSION+)"
            return 1
        fi
    else
        return 1
    fi
}

# Function to install Go on macOS
install_go_macos() {
    print_info "Installing Go using Homebrew..."
    if command_exists brew; then
        brew install go
    else
        print_error "Homebrew is not installed. Please install Homebrew first:"
        print_error "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
}

# Function to install Go on Linux
install_go_linux() {
    print_info "Installing Go on Linux..."
    if command_exists apt-get; then
        sudo apt-get update
        sudo apt-get install -y golang-go
    elif command_exists yum; then
        sudo yum install -y golang
    elif command_exists dnf; then
        sudo dnf install -y golang
    else
        print_error "Could not detect package manager. Please install Go manually from https://go.dev/dl/"
        exit 1
    fi
}

# Function to detect Windows
is_windows() {
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
        return 0
    fi
    # Check for WSL
    if [[ -f /proc/version ]] && grep -qi microsoft /proc/version; then
        return 0
    fi
    # Check for Git Bash on Windows
    if [[ "$(uname -s)" == "MINGW"* ]] || [[ "$(uname -s)" == "MSYS"* ]]; then
        return 0
    fi
    return 1
}

# Function to install Go on Windows
install_go_windows() {
    print_info "Installing Go on Windows..."
    
    # Try Chocolatey first
    if command_exists choco; then
        print_info "Using Chocolatey to install Go..."
        choco install golang -y
        # Refresh PATH
        export PATH="/c/Program Files/Go/bin:$PATH"
        return 0
    fi
    
    # Try winget (Windows Package Manager)
    if command_exists winget; then
        print_info "Using winget to install Go..."
        winget install GoLang.Go
        # Refresh PATH
        export PATH="/c/Program Files/Go/bin:$PATH"
        return 0
    fi
    
    # Try Scoop
    if command_exists scoop; then
        print_info "Using Scoop to install Go..."
        scoop install go
        return 0
    fi
    
    # If no package manager found, provide manual instructions
    print_error "No package manager found (Chocolatey, winget, or Scoop)."
    print_error "Please install Go manually:"
    print_error "  1. Download from https://go.dev/dl/"
    print_error "  2. Run the installer"
    print_error "  3. Restart your terminal"
    print_error ""
    print_error "Or install a package manager:"
    print_error "  - Chocolatey: https://chocolatey.org/install"
    print_error "  - Scoop: https://scoop.sh"
    print_error "  - winget: Usually pre-installed on Windows 10/11"
    exit 1
}

# Function to install Git
install_git() {
    print_info "Installing Git..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command_exists brew; then
            brew install git
        else
            print_error "Homebrew is not installed. Please install Git manually or install Homebrew first."
            exit 1
        fi
    elif is_windows; then
        # Try Chocolatey first
        if command_exists choco; then
            print_info "Using Chocolatey to install Git..."
            choco install git -y
            return 0
        fi
        
        # Try winget
        if command_exists winget; then
            print_info "Using winget to install Git..."
            winget install Git.Git
            return 0
        fi
        
        # Try Scoop
        if command_exists scoop; then
            print_info "Using Scoop to install Git..."
            scoop install git
            return 0
        fi
        
        print_error "No package manager found. Please install Git manually from https://git-scm.com/download/win"
        exit 1
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command_exists apt-get; then
            sudo apt-get update
            sudo apt-get install -y git
        elif command_exists yum; then
            sudo yum install -y git
        elif command_exists dnf; then
            sudo dnf install -y git
        else
            print_error "Could not detect package manager. Please install Git manually."
            exit 1
        fi
    else
        print_error "Unsupported OS. Please install Git manually."
        exit 1
    fi
}

# Function to install ios_webkit_debug_proxy
install_ios_webkit_debug_proxy() {
    print_info "Installing ios_webkit_debug_proxy..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command_exists brew; then
            brew install ios-webkit-debug-proxy
        else
            print_warn "Homebrew is not installed. Please install ios_webkit_debug_proxy manually:"
            print_warn "  https://github.com/google/ios-webkit-debug-proxy"
        fi
    elif is_windows; then
        # Try Chocolatey
        if command_exists choco; then
            print_info "Using Chocolatey to install ios-webkit-debug-proxy..."
            choco install ios-webkit-debug-proxy -y || {
                print_warn "Chocolatey package may not be available. Trying manual installation..."
                print_warn "Please install manually from: https://github.com/google/ios-webkit-debug-proxy"
            }
        elif command_exists winget; then
            print_info "Using winget to install ios-webkit-debug-proxy..."
            winget install ios-webkit-debug-proxy || {
                print_warn "winget package may not be available. Please install manually:"
                print_warn "  https://github.com/google/ios-webkit-debug-proxy"
            }
        else
            print_warn "No package manager found. Please install ios_webkit_debug_proxy manually:"
            print_warn "  https://github.com/google/ios-webkit-debug-proxy"
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        print_warn "ios_webkit_debug_proxy installation on Linux requires additional dependencies."
        print_warn "Please follow the instructions at: https://github.com/google/ios-webkit-debug-proxy"
    else
        print_warn "Please install ios_webkit_debug_proxy manually for your OS."
    fi
}

# Main installation process
main() {
    print_info "Starting installation of build requirements for ios-safari-remote-debug..."
    echo ""

    # Check and install Go
    if check_go_version; then
        print_info "Go is already installed with correct version"
    else
        print_info "Go is not installed or version is insufficient. Installing..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            install_go_macos
        elif is_windows; then
            install_go_windows
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            install_go_linux
        else
            print_error "Unsupported OS: $OSTYPE"
            print_error "Please install Go manually from https://go.dev/dl/"
            exit 1
        fi
        
        # Verify Go installation (may need to reload PATH on Windows)
        if ! check_go_version; then
            print_warn "Go may have been installed but PATH needs to be refreshed."
            print_warn "Please restart your terminal and run this script again, or add Go to your PATH manually."
            if is_windows; then
                print_info "On Windows, Go is typically installed to: C:\\Program Files\\Go\\bin"
                print_info "Add this to your PATH environment variable."
            fi
            exit 1
        fi
    fi
    echo ""

    # Check and install Git
    if command_exists git; then
        GIT_VERSION=$(git --version | awk '{print $3}')
        print_info "Git is already installed (version $GIT_VERSION)"
    else
        print_info "Git is not installed. Installing..."
        install_git
        
        if ! command_exists git; then
            print_error "Git installation failed"
            exit 1
        fi
        print_info "Git installed successfully"
    fi
    echo ""

    # Download Go dependencies
    print_info "Downloading Go module dependencies..."
    if [ -f "go.mod" ]; then
        go mod download
        print_info "Go dependencies downloaded successfully"
    else
        print_warn "go.mod not found. Skipping dependency download."
    fi
    echo ""

    # Ask about ios_webkit_debug_proxy (optional)
    print_info "ios_webkit_debug_proxy is required to run the debugger (not just build it)."
    if is_windows; then
        print_warn "Note: ios_webkit_debug_proxy on Windows may have limited support."
        print_warn "You may need to use WSL or a Linux environment for full functionality."
    fi
    read -p "Do you want to install ios_webkit_debug_proxy now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_ios_webkit_debug_proxy
    else
        print_warn "Skipping ios_webkit_debug_proxy installation."
        print_warn "You can install it later if needed for running the debugger."
    fi
    echo ""

    # Summary
    print_info "Installation complete!"
    echo ""
    print_info "Installed components:"
    echo "  - Go: $(go version)"
    echo "  - Git: $(git --version)"
    if command_exists ios_webkit_debug_proxy; then
        echo "  - ios_webkit_debug_proxy: $(ios_webkit_debug_proxy --version 2>/dev/null || echo 'installed')"
    else
        echo "  - ios_webkit_debug_proxy: not installed (optional for building, required for running)"
    fi
    echo ""
    print_info "You can now build the project with:"
    print_info "  go build"
    print_info ""
    print_info "Then build the debugger with:"
    if is_windows; then
        print_info "  ./ios-safari-remote-debug.exe build -t releases/Apple/Safari-17.5-macOS-14.5"
    else
        print_info "  ./ios-safari-remote-debug build -t releases/Apple/Safari-17.5-macOS-14.5"
    fi
}

# Run main function
main

