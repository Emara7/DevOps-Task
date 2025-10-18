# LGMT Stack Demo: EKS + Terraform + ArgoCD + Helm + OTel + Loki + Grafana

This repository delivers a simplified LGMT stack deployment focused on infrastructure, CI/CD, and observability.

- Infrastructure: EKS via Terraform with IRSA
- GitOps: ArgoCD deploys applications and observability stack
- App: Minimal NGINX Helm chart
- Observability (chosen signal): Logs via OpenTelemetry Collector to Loki, visualized in Grafana
- CI/CD: GitHub Actions validating and applying Terraform

## Prerequisites
- AWS account and permissions to create VPC, EKS, IAM
- Tools installed: awscli, kubectl, helm, terraform (1.5+), tflint, jq
- Optional (recommended): S3 bucket and DynamoDB table for Terraform remote state

## High-level Architecture
- A VPC with public/private subnets across multiple AZs
- An EKS cluster with managed node group(s) and IRSA enabled
- ArgoCD installed (bootstrap once with Helm) and configured with a root App-of-Apps
- Observability namespace installs Loki, Grafana, and an OpenTelemetry Collector DaemonSet that tails container logs and ships them to Loki
- A sample web app (NGINX) deployed via its own Helm chart

## Getting Started

### 1) Provision Infrastructure with Terraform
```
cd infra/terraform
terraform init
terraform fmt -recursive && tflint
terraform plan
terraform apply -auto-approve
aws eks update-kubeconfig --name <cluster_name> --region <region>
kubectl get nodes
```
Notes:
- This config defaults to the local backend. To use remote state, run `terraform init` with `-backend-config` flags for your S3 bucket and DynamoDB table.
- Adjust variables in `infra/terraform/variables.tf` as needed.

### 2) Bootstrap ArgoCD (one-time)
```
helm repo add argo https://argoproj.github.io/argo-helm
kubectl create ns argocd || true
helm upgrade --install argocd argo/argo-cd -n argocd
kubectl rollout status deploy/argocd-server -n argocd
```

### 3) Configure ArgoCD Root App
Edit `k8s/argocd/apps/*.yaml` and replace `REPO_URL_PLACEHOLDER` with your repo URL, then apply the root Application:
```
kubectl apply -n argocd -f k8s/argocd/apps/root-app.yaml
kubectl get applications.argoproj.io -n argocd
```
ArgoCD will create two child Applications:
- `observability` -> installs Loki, Grafana, and OTel Collector (DaemonSet) via an umbrella Helm chart in `k8s/observability`
- `web` -> deploys the sample NGINX application Helm chart in `k8s/apps/web`

### 4) Validate Observability
- Port-forward Grafana and login (default: admin/admin in demo values):
```
kubectl -n observability port-forward svc/grafana 3000:80
```
Open `http://localhost:3000`, explore the `Loki` datasource. You should see logs for the `web` service once traffic is generated.

- Generate traffic:
```
kubectl -n apps port-forward svc/web 8080:80
# in another terminal, send requests
curl -sS http://localhost:8080/ | head
```

## CI/CD (GitHub Actions)
The workflow `.github/workflows/terraform.yaml` validates Terraform (fmt, validate, tflint) and performs plan/apply using GitHub OIDC to assume an AWS role.

Setup:
- Create an AWS IAM role trusted for GitHub OIDC, granting IAM/VPC/EKS permissions
- Update the workflow `role-to-assume` and `aws-region`
- Push changes; PRs will run `plan`; merges to `main` will `apply`

## Assumptions and Simplifications
- Single EKS cluster and a single managed node group
- Demo-only credentials for Grafana (admin/admin) and no TLS (use only for non-production)
- Loki single-binary chart, in-cluster Grafana
- OTel Collector DaemonSet collects container logs via filelog and enriches with Kubernetes metadata, exporting to Loki

## Troubleshooting
- If ArgoCD Applications are OutOfSync, check that the repo URL is correct and reachable
- If Collector shows errors: verify it runs the `opentelemetry-collector-contrib` image (needed for the Loki exporter)
- If Grafana shows no logs: confirm Loki service name (`loki`) and exporter endpoint in `k8s/observability/values.yaml`

## Repository Layout
```
infra/terraform/                # VPC, EKS, IRSA
k8s/argocd/apps/                # ArgoCD Application manifests (root + children)
k8s/observability/              # Umbrella Helm chart: Loki, Grafana, OTel Collector
k8s/apps/web/                   # Sample NGINX Helm chart
.github/workflows/terraform.yaml# CI for Terraform
```
