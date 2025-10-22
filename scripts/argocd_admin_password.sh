#!/bin/bash
set -euo pipefail

echo "Getting ArgoCD initial admin password..."

# Wait for ArgoCD to be ready
echo "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get the admin password
echo "Retrieving admin password..."
PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)

if [ -z "$PASSWORD" ]; then
    echo "ERROR: Could not retrieve ArgoCD admin password"
    echo "Check if ArgoCD is running: kubectl get pods -n argocd"
    exit 1
fi

echo ""
echo "=== ArgoCD Access Information ==="
echo "Username: admin"
echo "Password: $PASSWORD"
echo ""
echo "Access ArgoCD at: http://$(minikube ip):30080"
echo "(NodePort may vary - check terraform.tfvars for actual port)"
echo ""
echo "Login with:"
echo "  Username: admin"
echo "  Password: $PASSWORD"
