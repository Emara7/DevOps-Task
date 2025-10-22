# Minikube LGMT Stack with ArgoCD and GitHub Webhook (Logs via Loki)

This repo provides a Minikube-based simplified LGMT stack deployment using Terraform, Helm, ArgoCD, GitHub Actions, and OpenTelemetry Collector. The chosen signal is logs, shipped to Loki and visualized in Grafana.

## Components

- Minikube (provisioned via Terraform local-exec script)
- ArgoCD (NodePort 30080), with GitHub webhook support
- Loki + Promtail
- Grafana (NodePort 32000) with Loki datasource
- OpenTelemetry Collector (DaemonSet) collecting container logs to Loki
- Sample app: NGINX-based Helm chart generating logs

## Prerequisites

- Linux VM with sudo, Docker, curl, and internet access. This solution is designed to run in the VM at `C:\Users\abdo\Documents\Virtual Machines\Devops-vm` (Windows host path), but commands are executed inside the Linux VM.
- GitHub repository: `https://github.com/Emara7/DevOps-Task.git` (use as the remote and add secrets below).

## Setup Steps (on the VM)

1) Clone or open this repository on the VM.

2) Apply Terraform:
```bash
cd infra/terraform
terraform init
terraform apply \
  -var="app_repo_url=https://github.com/Emara7/DevOps-Task.git" \
  -var="github_webhook_secret=$ARGOCD_WEBHOOK_SECRET"
```

3) Verify:
```bash
kubectl get pods -n argocd
kubectl get pods -n observability
kubectl get pods -n apps
```

4) Access UIs:
- ArgoCD: http://localhost:30080
- Grafana: http://localhost:32000 (admin/admin)

5) Configure GitHub → ArgoCD Webhook
- In GitHub repo settings → Webhooks: Add webhook
  - Payload URL: `http://<VM-IP>:30080/api/webhook` (use VM LAN IP)
  - Content type: `application/json`
  - Secret: same as `ARGOCD_WEBHOOK_SECRET`
  - Events: Just the push event

6) GitHub Actions
- Add repository secrets:
  - `ARGOCD_WEBHOOK_SECRET`: the shared secret
  - `ARGOCD_WEBHOOK_URL`: e.g., `http://<VM-IP>:30080/api/webhook`
- On pushes to `charts/**`, the workflow sends a signed webhook to ArgoCD.

## Notes and Assumptions

- Minikube is started using Docker driver by default. Adjust CPU/Memory via TF vars.
- ArgoCD is configured in insecure mode and NodePort for simplicity. Do not use in production.
- Logs: OTel Collector DaemonSet tails container logs and ships to Loki; Grafana pre-provisioned with Loki datasource.
- Sample app writes synthetic logs to `/var/log/app/access.log`; container logs are also collected by promtail/otel.

## Development

- Helm chart: `charts/sample-app`
- Terraform: `infra/terraform`

For more details, see `infra/terraform/README.md`.
