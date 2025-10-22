# Terraform for Minikube + ArgoCD + Loki + Grafana + OTel Collector

This module installs Minikube (locally on the VM), then installs ArgoCD, Loki, Grafana and OpenTelemetry Collector via Helm. It also wires an ArgoCD Application that points to a Helm chart (`charts/sample-app`).

## Usage

Ensure the VM has internet, and run:

```bash
cd infra/terraform
terraform init
terraform apply \
  -var="app_repo_url=https://github.com/Emara7/DevOps-Task.git" \
  -var="github_webhook_secret=YOUR_WEBHOOK_SECRET"
```

Notes:
- ArgoCD server will be exposed on NodePort 30080 (HTTP) and 30443 (HTTPS) in the `argocd` namespace.
- Grafana will be exposed on NodePort 32000 in the `observability` namespace (admin/admin).
- The OpenTelemetry Collector runs as a DaemonSet and ships container logs to Loki.

## Outputs

- `argocd_url`: http://localhost:30080
- `grafana_url`: http://localhost:32000
