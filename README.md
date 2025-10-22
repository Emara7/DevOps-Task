# Minikube + Terraform + ArgoCD Infrastructure

This repository contains the infrastructure layer for a local Kubernetes stack running on Ubuntu Server (6 GB RAM) using Minikube and Terraform, with GitHub Actions for CI/CD.

## 🏗️ Architecture

- **Minikube**: Local Kubernetes cluster
- **Terraform**: Infrastructure as Code
- **ArgoCD**: GitOps continuous deployment
- **GitHub Actions**: CI/CD pipeline
- **Nginx**: Sample application

## 🚀 Quick Start

### Prerequisites
- Ubuntu Server with 6 GB RAM
- Docker
- kubectl
- Helm
- Minikube
- Terraform
- make

### Local Development

1. **Start the infrastructure:**
   ```bash
   make up
   ```

2. **Get ArgoCD admin password:**
   ```bash
   make argocd-pass
   ```

3. **Access ArgoCD:**
   - URL: http://$(minikube ip):30080
   - Username: admin
   - Password: (from step 2)

### GitHub Integration

1. **Push to GitHub:**
   ```bash
   git add .
   git commit -m "Initial infrastructure setup"
   git push origin main
   ```

2. **GitHub Actions will:**
   - Run Terraform validation
   - Deploy to Minikube (if on main branch)
   - Sync ArgoCD applications

## 📁 Repository Structure

```
.
├── .github/workflows/          # GitHub Actions
│   ├── ci-cd.yml               # CI/CD pipeline
│   └── gitops.yml              # GitOps sync
├── argocd/apps/                # ArgoCD applications
│   └── nginx-deployment.yaml  # Nginx app manifests
├── infra/terraform/           # Terraform configuration
│   ├── versions.tf
│   ├── providers.tf
│   ├── variables.tf
│   ├── namespaces.tf
│   ├── argocd.tf
│   └── argocd_root_app.tf
├── scripts/                   # Bootstrap scripts
│   ├── mk_start.sh
│   ├── mk_tunnel.sh
│   └── argocd_admin_password.sh
├── Makefile                   # Local development commands
└── README.md
```

## 🔄 GitOps Workflow

1. **Develop**: Make changes to manifests in `argocd/apps/`
2. **Commit**: Push changes to GitHub
3. **Automate**: GitHub Actions runs CI/CD pipeline
4. **Deploy**: ArgoCD automatically syncs changes to cluster
5. **Monitor**: View status in ArgoCD UI

## 🛠️ Available Commands

- `make up` - Start Minikube and deploy infrastructure
- `make down` - Destroy infrastructure and delete Minikube
- `make status` - Show cluster status and pods by namespace
- `make argocd-pass` - Get ArgoCD initial admin password

## 🌐 Access Points

- **ArgoCD UI**: http://$(minikube ip):30080
- **Nginx App**: http://$(minikube ip):30081
- **Minikube IP**: `minikube ip`

## 🔧 GitHub Actions Secrets

To enable full GitHub Actions functionality, add these secrets to your repository:

- `ARGOCD_PASSWORD`: ArgoCD admin password
- `KUBECONFIG`: Base64 encoded kubeconfig (for remote deployment)

## 📊 Monitoring

- **ArgoCD**: Application sync status and health
- **Kubernetes**: Pod and service status
- **GitHub Actions**: CI/CD pipeline status

## 🚀 Next Steps

1. **Add more applications** to `argocd/apps/`
2. **Configure monitoring** with Loki, Grafana, OpenTelemetry
3. **Set up production** deployment targets
4. **Add security scanning** to CI/CD pipeline

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Push to GitHub
5. Create a pull request

## 📝 License

This project is licensed under the MIT License.