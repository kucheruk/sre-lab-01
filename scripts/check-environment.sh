#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
CHECKS_PASSED=0
CHECKS_TOTAL=0

echo -e "${BLUE}🔍 Checking Lab 1 environment...${NC}\n"

# Function to print status
check_passed() {
    echo -e "${GREEN}✅ $1${NC}"
    ((CHECKS_PASSED++)) || true
    ((CHECKS_TOTAL++)) || true
}

check_failed() {
    echo -e "${RED}❌ $1${NC}"
    ((CHECKS_TOTAL++)) || true
}

check_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    ((CHECKS_TOTAL++)) || true
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check operating system
print_info "System Information:"
echo "  OS: $(uname -s) $(uname -r)"
echo "  Architecture: $(uname -m)"
echo "  macOS Version: $(sw_vers -productVersion 2>/dev/null || echo 'Not macOS')"
echo ""

# Check required tools
print_info "Checking required tools..."

# Docker
if command -v docker &>/dev/null; then
    docker_version=$(docker --version | awk '{print $3}' | sed 's/,//')
    if docker info &>/dev/null; then
        check_passed "Docker ($docker_version) - running"
    else
        check_failed "Docker ($docker_version) - daemon not running"
        echo "  💡 Please start Docker Desktop"
    fi
else
    check_failed "Docker - not installed"
    echo "  💡 Install with: brew install --cask docker"
fi

# k3d
if command -v k3d &>/dev/null; then
    k3d_version=$(k3d version | grep k3d | awk '{print $3}')
    if [[ $k3d_version =~ ^v5\. ]]; then
        check_passed "k3d ($k3d_version)"
    else
        check_warning "k3d ($k3d_version) - v5.x recommended"
    fi
else
    check_failed "k3d - not installed"
    echo "  💡 Install with: brew install k3d"
fi

# kubectl
if command -v kubectl &>/dev/null; then
    kubectl_version=$(kubectl version --client -o json 2>/dev/null | jq -r '.clientVersion.gitVersion' 2>/dev/null || echo "unknown")
    check_passed "kubectl ($kubectl_version)"
else
    check_failed "kubectl - not installed"
    echo "  💡 Install with: brew install kubectl"
fi

# k6
if command -v k6 &>/dev/null; then
    k6_version=$(k6 version | head -1 | awk '{print $2}')
    check_passed "k6 ($k6_version)"
else
    check_failed "k6 - not installed"
    echo "  💡 Install with: brew install k6"
fi

# Git
if command -v git &>/dev/null; then
    git_version=$(git --version | awk '{print $3}')
    check_passed "git ($git_version)"
else
    check_failed "git - not installed"
    echo "  💡 Install with: brew install git"
fi

# jq (optional but helpful)
if command -v jq &>/dev/null; then
    jq_version=$(jq --version | sed 's/jq-//')
    check_passed "jq ($jq_version) - optional tool"
else
    check_warning "jq - not installed (optional but recommended)"
    echo "  💡 Install with: brew install jq"
fi

echo ""

# Check system resources
print_info "Checking system resources..."

# RAM
total_ram=$(sysctl hw.memsize 2>/dev/null | awk '{print int($2/1024/1024/1024)}' || echo "0")
if [[ $total_ram -ge 16 ]]; then
    check_passed "RAM: ${total_ram}GB (excellent)"
elif [[ $total_ram -ge 8 ]]; then
    check_warning "RAM: ${total_ram}GB (minimum requirement met)"
else
    check_failed "RAM: ${total_ram}GB (insufficient, 8GB+ required)"
fi

# Available disk space
available_space=$(df -h . | awk 'NR==2{print $4}')
available_gb=$(echo $available_space | sed 's/[^0-9]*//g')
if [[ $available_gb -ge 20 ]]; then
    check_passed "Disk space: ${available_space} available"
elif [[ $available_gb -ge 10 ]]; then
    check_warning "Disk space: ${available_space} available (10GB+ recommended)"
else
    check_failed "Disk space: ${available_space} available (insufficient)"
fi

echo ""

# Check ports availability
print_info "Checking port availability..."
required_ports=(3000 8080 9090 16686)
for port in "${required_ports[@]}"; do
    if ! lsof -i :$port &>/dev/null; then
        check_passed "Port $port - available"
    else
        check_warning "Port $port - in use (may cause conflicts)"
        echo "  💡 Process using port: $(lsof -i :$port | tail -n1 | awk '{print $1}')"
    fi
done

echo ""

# Docker-specific checks
if command -v docker &>/dev/null && docker info &>/dev/null; then
    print_info "Docker configuration checks..."
    
    # Docker memory allocation
    docker_memory=$(docker system info --format '{{.MemTotal}}' 2>/dev/null || echo "0")
    if [[ $docker_memory -gt 0 ]]; then
        docker_memory_gb=$((docker_memory / 1024 / 1024 / 1024))
        if [[ $docker_memory_gb -ge 4 ]]; then
            check_passed "Docker memory: ${docker_memory_gb}GB allocated"
        else
            check_warning "Docker memory: ${docker_memory_gb}GB allocated (4GB+ recommended)"
            echo "  💡 Increase in Docker Desktop → Settings → Resources → Memory"
        fi
    fi
    
    # Docker CPU allocation
    docker_cpus=$(docker system info --format '{{.NCPU}}' 2>/dev/null || echo "0")
    if [[ $docker_cpus -ge 2 ]]; then
        check_passed "Docker CPUs: $docker_cpus allocated"
    else
        check_warning "Docker CPUs: $docker_cpus allocated (2+ recommended)"
    fi
    
    echo ""
fi

# Check for existing k3d clusters
if command -v k3d &>/dev/null; then
    print_info "Checking for existing k3d clusters..."
    # Use safer approach to count clusters
    existing_clusters=$(k3d cluster list -o json 2>/dev/null | jq -r '. | length' 2>/dev/null || echo "0")
    if [[ $existing_clusters -eq 0 ]]; then
        check_passed "No existing k3d clusters (clean state)"
    else
        check_warning "$existing_clusters existing k3d cluster(s) found"
        echo "  💡 List clusters: k3d cluster list"
        echo "  💡 Delete cluster: k3d cluster delete <name>"
    fi
fi

echo ""

# Final summary
echo -e "${BLUE}📊 Environment Check Summary${NC}"
echo "==============================="
if [[ $CHECKS_PASSED -eq $CHECKS_TOTAL ]]; then
    echo -e "${GREEN}🎉 All checks passed! ($CHECKS_PASSED/$CHECKS_TOTAL)${NC}"
    echo -e "${GREEN}Your environment is ready for Lab 1!${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Run: ./scripts/setup-cluster.sh"
    echo "2. Verify: ./scripts/verify-setup.sh"
    echo "3. Start load testing: K6_RPS=100 k6 run scripts/load.js"
elif [[ $CHECKS_PASSED -gt $((CHECKS_TOTAL * 3 / 4)) ]]; then
    echo -e "${YELLOW}⚠️  Most checks passed ($CHECKS_PASSED/$CHECKS_TOTAL)${NC}"
    echo -e "${YELLOW}You can proceed but may encounter minor issues.${NC}"
    echo ""
    echo -e "${BLUE}Recommended actions:${NC}"
    echo "1. Address the warnings above"
    echo "2. Run: ./scripts/setup-cluster.sh"
else
    echo -e "${RED}❌ Several checks failed ($CHECKS_PASSED/$CHECKS_TOTAL)${NC}"
    echo -e "${RED}Please fix the issues above before proceeding.${NC}"
    echo ""
    echo -e "${BLUE}Required actions:${NC}"
    echo "1. Install missing tools (see errors above)"
    echo "2. Start Docker Desktop"
    echo "3. Rerun this script: ./scripts/check-environment.sh"
    exit 1
fi

# Additional recommendations
echo ""
echo -e "${BLUE}💡 Pro Tips:${NC}"
echo "• Keep Docker Desktop running in the background"
echo "• Increase Docker memory to 6-8GB for better performance"
echo "• Close unnecessary applications to free up RAM"
echo "• Use 'docker system prune' occasionally to clean up disk space" 