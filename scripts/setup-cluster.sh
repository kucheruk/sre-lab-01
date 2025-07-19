#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🚀 Setting up Lab 1 cluster...${NC}"

# Check if required tools are installed
if ! command -v k3d &> /dev/null; then
    echo "❌ k3d is not installed. Please run ./scripts/setup-macos.sh first."
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed. Please run ./scripts/setup-macos.sh first."
    exit 1
fi

# Check if cluster exists
if k3d cluster list | grep -q "lab1"; then
    echo -e "${YELLOW}📦 Cluster 'lab1' already exists. Checking if it's running...${NC}"
    
    # Check if cluster is running
    if ! kubectl cluster-info &>/dev/null; then
        echo "🔄 Cluster exists but not accessible. Starting..."
        k3d cluster start lab1 || {
            echo "🗑️  Failed to start cluster. Deleting and recreating..."
            k3d cluster delete lab1
            CREATE_CLUSTER=true
        }
    else
        echo -e "${GREEN}✅ Cluster is running${NC}"
        CREATE_CLUSTER=false
    fi
else
    CREATE_CLUSTER=true
fi

# Create cluster if needed
if [ "$CREATE_CLUSTER" = true ]; then
    echo -e "${BLUE}📦 Creating k3d cluster...${NC}"
    k3d cluster create lab1 \
      --servers 1 \
      --agents 2 \
      --port "8080:80@loadbalancer" \
      --port "9090:9090@loadbalancer" \
      --port "3000:3000@loadbalancer" \
      --port "16686:16686@loadbalancer" \
      --k3s-arg "--disable=traefik@server:0" \
      --wait

    echo "⏳ Waiting for cluster to be ready..."
    kubectl wait --for=condition=ready node --all --timeout=300s
fi

# Build orders-api image if needed
echo -e "${BLUE}🔨 Building orders-api Docker image...${NC}"
if docker images | grep -q "orders-api.*latest"; then
    echo -e "${YELLOW}📦 Docker image 'orders-api:latest' already exists. Rebuilding with latest code...${NC}"
fi

cd src/orders-api
docker build -t orders-api:latest .

# Import image to k3d cluster
if k3d image list lab1 | grep -q "orders-api:latest"; then
    echo -e "${YELLOW}📦 Image already imported to cluster. Reimporting...${NC}"
    k3d image import orders-api:latest --cluster lab1 --mode overwrite
else
    echo -e "${BLUE}📦 Importing image to cluster...${NC}"
    k3d image import orders-api:latest --cluster lab1
fi
cd ../..

# Apply Kubernetes manifests
echo -e "${BLUE}📋 Applying Kubernetes manifests...${NC}"

# Check if namespace exists
if kubectl get namespace lab1 &>/dev/null; then
    echo -e "${YELLOW}📁 Namespace 'lab1' already exists${NC}"
else
    echo -e "${BLUE}📁 Creating namespace 'lab1'${NC}"
    kubectl apply -f k8s/namespace.yaml
fi

# Apply manifests (kubectl apply is idempotent)
echo -e "${BLUE}🚀 Applying orders-api manifests...${NC}"
kubectl apply -f k8s/orders-api/

echo -e "${BLUE}📊 Applying monitoring manifests...${NC}"  
kubectl apply -f k8s/monitoring/

# Wait for deployments
echo -e "${BLUE}⏳ Waiting for deployments to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment --all -n lab1

# Create port forwards
echo -e "${BLUE}🔌 Setting up port forwards...${NC}"

# Function to start port forwarding with retry
start_port_forward() {
    local port=$1
    local service=$2
    local local_port=$3
    local service_port=$4
    
    if lsof -i :$local_port &>/dev/null; then
        echo -e "${YELLOW}🔌 Port $local_port already in use${NC}"
        return 0
    fi
    
    echo -e "${BLUE}🔌 Creating port forward for $service on port $local_port${NC}"
    kubectl port-forward -n lab1 svc/$service $local_port:$service_port &
    local pf_pid=$!
    
    # Wait a bit and check if port forward is working
    sleep 3
    if kill -0 $pf_pid 2>/dev/null && lsof -i :$local_port &>/dev/null; then
        echo -e "${GREEN}✅ Port forward for $service established${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  Port forward for $service may have failed, but continuing...${NC}"
        return 1
    fi
}

# Start port forwards with proper error handling
start_port_forward orders-api 8080 80
start_port_forward prometheus 9090 9090  
start_port_forward grafana 3000 3000
start_port_forward jaeger 16686 16686

# Additional wait to ensure port forwards are stable
sleep 2

# Import Grafana dashboard
echo -e "${BLUE}📊 Setting up Grafana dashboard...${NC}"

# Wait for Grafana to be ready
echo "⏳ Waiting for Grafana to be accessible..."
for i in {1..30}; do
    if curl -s http://admin:lab1pass@localhost:3000/api/health &>/dev/null; then
        echo -e "${GREEN}✅ Grafana is ready${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${YELLOW}⚠️  Grafana might not be ready yet, but continuing...${NC}"
    fi
    sleep 2
done

# Check if dashboard already exists
if curl -s http://admin:lab1pass@localhost:3000/api/dashboards/uid/slo-draft | grep -q "slo-draft"; then
    echo -e "${YELLOW}📊 Dashboard already exists, updating...${NC}"
    # Dashboard will be updated if JSON content differs
else
    echo -e "${BLUE}📊 Creating new dashboard...${NC}"
fi

# Create/update the dashboard using Grafana API
if curl -X POST \
  http://admin:lab1pass@localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @dashboards/slo-draft.json \
  -w "%{http_code}" -o /dev/null -s | grep -q "200"; then
    echo -e "${GREEN}✅ Dashboard imported successfully${NC}"
else
    echo -e "${YELLOW}⚠️  Dashboard import may have failed, but continuing...${NC}"
fi

echo ""
echo -e "${GREEN}✅ Lab 1 cluster setup complete!${NC}"
echo ""
echo -e "${BLUE}🔗 Access points:${NC}"
echo "  - Orders API: http://localhost:8080"
echo "  - Prometheus: http://localhost:9090"
echo "  - Grafana: http://localhost:3000 (admin/lab1pass)"
echo "  - Jaeger: http://localhost:16686"
echo ""
echo -e "${BLUE}🧪 Next steps:${NC}"
echo "  1. Test the API: curl http://localhost:8080/health"
echo "  2. Run load test: K6_RPS=100 k6 run scripts/load.js"
echo "  3. Check the setup: ./scripts/verify-setup.sh"
echo ""
echo -e "${YELLOW}💡 Pro tip: This script is idempotent - you can run it multiple times safely!${NC}" 