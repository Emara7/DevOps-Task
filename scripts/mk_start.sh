#!/bin/bash
set -euo pipefail

echo "=== Starting Minikube with optimized settings for 6GB RAM ==="

# Check if swap is enabled and warn
if swapon --show | grep -q .; then
    echo "WARNING: Swap is enabled. Disabling swap for better Kubernetes performance..."
    sudo swapoff -a
    echo "Swap disabled. Consider removing swap entries from /etc/fstab for permanent change."
else
    echo "✓ Swap is already disabled"
fi

# Check if Minikube is already running
if minikube status >/dev/null 2>&1; then
    echo "Minikube is already running. Stopping and deleting existing cluster..."
    minikube delete
fi

echo "Starting Minikube with Docker driver..."
minikube start \
    --driver=docker \
    --cpus=3 \
    --memory=4096 \
    --disk-size=20g \
    --kubernetes-version=1.29.0

echo "Enabling required addons..."
minikube addons enable metrics-server
minikube addons enable ingress

echo "Setting up Docker environment..."
eval $(minikube docker-env)

echo "=== Minikube Status ==="
minikube status

echo ""
echo "=== Cluster Information ==="
echo "Minikube IP: $(minikube ip)"
echo "Current context: $(kubectl config current-context)"

echo ""
echo "✓ Minikube is ready!"
echo "Next: Run 'make up' to deploy infrastructure with Terraform"
