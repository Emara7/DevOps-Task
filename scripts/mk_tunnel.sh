#!/bin/bash
set -euo pipefail

echo "Starting Minikube tunnel for LoadBalancer services..."
echo "This will run in the foreground. Press Ctrl+C to stop."
echo ""

# Check if Minikube is running
if ! minikube status >/dev/null 2>&1; then
    echo "ERROR: Minikube is not running. Please start Minikube first with 'make up'"
    exit 1
fi

echo "Starting tunnel..."
minikube tunnel
