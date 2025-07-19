#!/bin/bash
set -e

echo "🔍 Verifying Lab 1 setup..."

# Check cluster
echo "✓ Checking k3d cluster..."
k3d cluster list | grep lab1

# Check pods
echo "✓ Checking pods in lab1 namespace..."
kubectl get pods -n lab1

# Test Orders API
echo "✓ Testing Orders API..."
curl -s -o /dev/null -w "Health check: %{http_code}\n" http://localhost:8080/health
curl -s -o /dev/null -w "Get orders: %{http_code}\n" http://localhost:8080/api/orders

# Test Prometheus
echo "✓ Testing Prometheus..."
curl -s -o /dev/null -w "Prometheus: %{http_code}\n" http://localhost:9090/-/healthy

# Test Grafana
echo "✓ Testing Grafana..."
curl -s -o /dev/null -w "Grafana: %{http_code}\n" http://localhost:3000/api/health

# Test metrics endpoint
echo "✓ Checking metrics..."
curl -s http://localhost:8080/metrics | grep -E "http_request_duration_seconds|http_requests_total" | head -5

echo ""
echo "✅ All systems operational!" 