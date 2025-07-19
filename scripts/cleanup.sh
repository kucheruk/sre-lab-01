#!/bin/bash
echo "🧹 Cleaning up Lab 1..."

# Kill port forwards
echo "Stopping port forwards..."
pkill -f "kubectl port-forward" || true

# Delete k3d cluster
echo "Deleting k3d cluster..."
k3d cluster delete lab1

echo "✅ Cleanup complete!" 