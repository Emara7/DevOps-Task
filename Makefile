SHELL := /usr/bin/env bash -eo pipefail

.PHONY: up down status argocd-pass clean

# Start Minikube and deploy infrastructure
up:
	@echo "Starting Minikube and deploying infrastructure..."
	./scripts/mk_start.sh
	@echo "Initializing and applying Terraform..."
	terraform -chdir=infra/terraform init
	terraform -chdir=infra/terraform apply -auto-approve
	@echo "Infrastructure deployed successfully!"
	@echo "Get ArgoCD admin password with: make argocd-pass"

# Destroy infrastructure and delete Minikube
down:
	@echo "Destroying infrastructure..."
	terraform -chdir=infra/terraform destroy -auto-approve
	@echo "Deleting Minikube cluster..."
	minikube delete
	@echo "Cleanup completed!"

# Show cluster status and pods by namespace
status:
	@echo "=== Minikube Status ==="
	minikube status
	@echo ""
	@echo "=== Nodes ==="
	kubectl get nodes
	@echo ""
	@echo "=== Pods by Namespace ==="
	@for ns in argocd observability apps; do \
		echo "--- $$ns namespace ---"; \
		kubectl get pods -n $$ns 2>/dev/null || echo "No pods in $$ns namespace"; \
		echo ""; \
	done

# Get ArgoCD initial admin password
argocd-pass:
	@echo "Getting ArgoCD admin password..."
	./scripts/argocd_admin_password.sh

# Clean up temporary files
clean:
	@echo "Cleaning up temporary files..."
	rm -rf infra/terraform/.terraform
	rm -f infra/terraform/.terraform.lock.hcl
	@echo "Cleanup completed!"

# Setup GitHub repository
github-setup:
	@echo "Setting up GitHub repository..."
	./scripts/setup-github.sh

# Push to GitHub
github-push:
	@echo "Pushing to GitHub..."
	git add .
	git commit -m "Update infrastructure and applications" || echo "No changes to commit"
	git push origin main

# Show GitHub Actions status
github-status:
	@echo "GitHub Actions status:"
	@echo "Visit: https://github.com/$(git config --get remote.origin.url | sed 's/.*github.com[:/]\([^/]*\/[^/]*\)\.git.*/\1/')/actions"
