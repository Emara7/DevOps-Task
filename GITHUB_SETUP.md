# GitHub Integration Setup Guide

This guide will help you integrate your Minikube + ArgoCD infrastructure with GitHub and GitHub Actions for a complete GitOps workflow.

## 🚀 Quick Setup

### 1. Initialize Git Repository
```bash
# Initialize git repository
git init
git branch -M main

# Add all files
git add .

# Create initial commit
git commit -m "Initial infrastructure setup with Minikube, Terraform, and ArgoCD"
```

### 2. Create GitHub Repository
1. Go to [GitHub](https://github.com/new)
2. Repository name: `minikube-argocd-infra`
3. Make it public or private
4. **Don't** initialize with README (we already have one)
5. Click "Create repository"

### 3. Connect Local Repository to GitHub
```bash
# Add remote origin (replace YOUR_USERNAME with your GitHub username)
git remote add origin https://github.com/YOUR_USERNAME/minikube-argocd-infra.git

# Push to GitHub
git push -u origin main
```

### 4. Set Up GitHub Actions Secrets (Optional)
1. Go to your repository on GitHub
2. Click "Settings" > "Secrets and variables" > "Actions"
3. Add these secrets:
   - `ARGOCD_PASSWORD`: Get this with `make argocd-pass`
   - `KUBECONFIG`: Base64 encoded kubeconfig (for remote deployment)

## 🔄 GitOps Workflow

### Development Workflow
1. **Make changes** to manifests in `argocd/apps/`
2. **Commit changes**: `git add . && git commit -m "Update nginx app"`
3. **Push to GitHub**: `git push origin main`
4. **GitHub Actions** automatically runs CI/CD pipeline
5. **ArgoCD** automatically syncs changes to cluster

### Available Commands
```bash
# Setup GitHub repository
make github-setup

# Push changes to GitHub
make github-push

# Check GitHub Actions status
make github-status
```

## 📁 Repository Structure

```
.
├── .github/workflows/          # GitHub Actions
│   ├── ci-cd.yml               # CI/CD pipeline
│   ├── gitops.yml              # GitOps sync
│   └── deploy.yml              # Deploy to Minikube
├── argocd/apps/                # ArgoCD applications
│   └── nginx-deployment.yaml   # Nginx app manifests
├── infra/terraform/            # Terraform configuration
├── scripts/                    # Bootstrap scripts
├── Makefile                    # Local development commands
└── README.md
```

## 🛠️ GitHub Actions Workflows

### 1. CI/CD Pipeline (`.github/workflows/ci-cd.yml`)
- **Triggers**: Push to main/develop, Pull requests
- **Actions**:
  - Terraform format check
  - Terraform validation
  - Terraform plan

### 2. GitOps Sync (`.github/workflows/gitops.yml`)
- **Triggers**: Push to main (when ArgoCD apps change)
- **Actions**:
  - Sync ArgoCD applications
  - Update deployments

### 3. Deploy to Minikube (`.github/workflows/deploy.yml`)
- **Triggers**: Push to main, Manual dispatch
- **Actions**:
  - Start Minikube
  - Deploy infrastructure
  - Deploy applications
  - Verify deployment

## 🔧 Configuration

### ArgoCD Application Configuration
Update `argocd-apps-config.yaml` with your GitHub repository URL:

```yaml
spec:
  source:
    repoURL: https://github.com/YOUR_USERNAME/minikube-argocd-infra
    path: argocd/apps
    targetRevision: main
```

### GitHub Actions Secrets
Add these secrets to your GitHub repository:

1. **ARGOCD_PASSWORD**: ArgoCD admin password
   ```bash
   # Get the password
   make argocd-pass
   ```

2. **KUBECONFIG**: Base64 encoded kubeconfig (for remote deployment)
   ```bash
   # Get kubeconfig
   kubectl config view --raw | base64 -w 0
   ```

## 🚀 Testing the Workflow

### 1. Test Local Changes
```bash
# Make a change to nginx app
echo "Hello from GitOps!" > argocd/apps/nginx-deployment.yaml

# Commit and push
git add .
git commit -m "Update nginx app"
git push origin main
```

### 2. Monitor GitHub Actions
1. Go to your repository on GitHub
2. Click "Actions" tab
3. Watch the workflow run

### 3. Check ArgoCD
1. Access ArgoCD UI: http://$(minikube ip):30080
2. Check application sync status
3. Verify nginx app is updated

## 🔍 Troubleshooting

### Common Issues

1. **GitHub Actions failing**:
   - Check repository secrets
   - Verify workflow syntax
   - Check logs in Actions tab

2. **ArgoCD not syncing**:
   - Verify repository URL in ArgoCD application
   - Check ArgoCD server logs
   - Ensure proper authentication

3. **Minikube issues**:
   - Check Minikube status
   - Verify resource limits
   - Check Docker daemon

### Debug Commands
```bash
# Check GitHub Actions status
make github-status

# Check ArgoCD applications
kubectl get applications -n argocd

# Check pod status
kubectl get pods -n apps

# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-server
```

## 🎯 Next Steps

1. **Add more applications** to `argocd/apps/`
2. **Configure monitoring** with Loki, Grafana, OpenTelemetry
3. **Set up production** deployment targets
4. **Add security scanning** to CI/CD pipeline
5. **Implement blue-green deployments**

## 📚 Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Terraform Documentation](https://terraform.io/docs)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Push to GitHub
5. Create a pull request

Your infrastructure is now fully integrated with GitHub and GitHub Actions! 🎉
