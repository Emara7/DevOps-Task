#!/bin/bash
set -euo pipefail

echo "=== Setting up GitHub repository ==="

# Check if git is initialized
if [ ! -d ".git" ]; then
    echo "Initializing git repository..."
    git init
    git branch -M main
fi

# Add all files
echo "Adding files to git..."
git add .

# Create initial commit
echo "Creating initial commit..."
git commit -m "Initial infrastructure setup with Minikube, Terraform, and ArgoCD"

# Check if remote exists
if ! git remote get-url origin >/dev/null 2>&1; then
    echo ""
    echo "=== GitHub Repository Setup ==="
    echo "1. Create a new repository on GitHub:"
    echo "   - Go to https://github.com/new"
    echo "   - Repository name: minikube-argocd-infra"
    echo "   - Make it public or private"
    echo "   - Don't initialize with README (we already have one)"
    echo ""
    echo "2. Add the remote origin:"
    echo "   git remote add origin https://github.com/YOUR_USERNAME/minikube-argocd-infra.git"
    echo ""
    echo "3. Push to GitHub:"
    echo "   git push -u origin main"
    echo ""
    echo "4. Set up GitHub Actions secrets (optional):"
    echo "   - Go to Settings > Secrets and variables > Actions"
    echo "   - Add ARGOCD_PASSWORD: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
    echo ""
else
    echo "Remote origin already exists. Pushing to GitHub..."
    git push origin main
fi

echo ""
echo "=== Repository setup complete! ==="
echo "Your infrastructure is now ready for GitHub integration."
