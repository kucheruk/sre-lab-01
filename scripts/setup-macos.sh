#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Setting up Lab 1 environment on macOS...${NC}\n"

# Function to print status
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if we're on Apple Silicon
if [[ $(uname -m) != "arm64" ]]; then
    print_warning "This script is optimized for Apple Silicon. Intel Macs may work but are not tested."
fi

# Check macOS version
macos_version=$(sw_vers -productVersion)
print_info "macOS version: $macos_version"

if [[ $(echo $macos_version | cut -d. -f1) -lt 12 ]]; then
    print_error "macOS 12.0 (Monterey) or later is required"
    exit 1
fi

# Install Xcode Command Line Tools if needed
print_info "Checking Xcode Command Line Tools..."
if ! xcode-select -p &>/dev/null; then
    print_info "Installing Xcode Command Line Tools..."
    xcode-select --install
    echo "Please complete the Xcode Command Line Tools installation and rerun this script."
    exit 0
else
    print_status "Xcode Command Line Tools already installed"
fi

# Install Homebrew if not present
print_info "Checking Homebrew installation..."
if ! command -v brew &>/dev/null; then
    print_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for Apple Silicon
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
    print_status "Homebrew installed successfully"
else
    print_status "Homebrew already installed"
    # Update Homebrew
    brew update &>/dev/null || print_warning "Failed to update Homebrew (continuing anyway)"
fi

# Ensure Homebrew is in PATH
if ! command -v brew &>/dev/null; then
    print_info "Adding Homebrew to current session PATH..."
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Install Docker Desktop if not present
print_info "Checking Docker Desktop..."
docker_installed=false

# Check if Docker.app exists
if [ -d "/Applications/Docker.app" ]; then
    print_status "Docker Desktop found in Applications"
    docker_installed=true
# Check if Docker is available via brew cask
elif brew list --cask docker &>/dev/null; then
    print_status "Docker Desktop installed via Homebrew"
    docker_installed=true
# Check if docker command is available
elif command -v docker &>/dev/null; then
    print_status "Docker command available"
    docker_installed=true
fi

if [ "$docker_installed" = false ]; then
    print_info "Installing Docker Desktop..."
    brew install --cask docker
    print_status "Docker Desktop installed"
    print_warning "Please start Docker Desktop from Applications folder"
    print_warning "Make sure to allocate at least 4GB RAM to Docker in preferences"
else
    print_status "Docker Desktop already available"
fi

# Check if Docker is running
print_info "Checking Docker daemon..."
if ! docker info &>/dev/null; then
    print_warning "Docker daemon is not running. Please start Docker Desktop."
else
    print_status "Docker daemon is running"
fi

# Install k3d
print_info "Checking k3d..."
if ! command -v k3d &>/dev/null; then
    print_info "Installing k3d..."
    brew install k3d
    print_status "k3d installed successfully"
else
    current_k3d=$(k3d version | grep k3d | awk '{print $3}')
    print_status "k3d already installed (version: $current_k3d)"
fi

# Install kubectl
print_info "Checking kubectl..."
if ! command -v kubectl &>/dev/null; then
    print_info "Installing kubectl..."
    brew install kubectl
    print_status "kubectl installed successfully"
else
    current_kubectl=$(kubectl version --client -o json 2>/dev/null | jq -r '.clientVersion.gitVersion' 2>/dev/null || echo "unknown")
    print_status "kubectl already installed (version: $current_kubectl)"
fi

# Install k6
print_info "Checking k6..."
if ! command -v k6 &>/dev/null; then
    print_info "Installing k6..."
    brew install k6
    print_status "k6 installed successfully"
else
    current_k6=$(k6 version | head -1 | awk '{print $2}')
    print_status "k6 already installed (version: $current_k6)"
fi

# Install optional but useful tools
print_info "Installing additional tools..."
tools=("git" "curl" "wget" "jq")
for tool in "${tools[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
        print_info "Installing $tool..."
        brew install "$tool"
        print_status "$tool installed"
    else
        print_status "$tool already available"
    fi
done

# Check system resources
print_info "Checking system resources..."
total_ram=$(sysctl hw.memsize | awk '{print int($2/1024/1024/1024)}')
if [[ $total_ram -lt 8 ]]; then
    print_error "At least 8GB RAM is required (found ${total_ram}GB)"
    exit 1
elif [[ $total_ram -lt 16 ]]; then
    print_warning "16GB RAM is recommended for optimal performance (found ${total_ram}GB)"
else
    print_status "RAM check passed (${total_ram}GB available)"
fi

# Check available disk space
available_space=$(df -h . | awk 'NR==2{print $4}' | sed 's/Gi*//')
if [[ $(echo "$available_space < 10" | bc 2>/dev/null) -eq 1 ]]; then
    print_warning "Low disk space: ${available_space}GB available (10GB+ recommended)"
else
    print_status "Disk space check passed (${available_space}GB available)"
fi

# Create necessary directories
print_info "Creating project directories..."
mkdir -p ~/lab-environments/lab01
print_status "Project directories created"

echo -e "\n${GREEN}🎉 macOS setup completed successfully!${NC}\n"
echo -e "${BLUE}Next steps:${NC}"
echo "1. Start Docker Desktop if not already running"
echo "2. Run './scripts/check-environment.sh' to verify everything is working"
echo "3. Follow the Quick Start guide in README.md"
echo ""
echo -e "${YELLOW}Note: If you just installed Docker Desktop, please restart it and wait for it to fully initialize before proceeding.${NC}" 