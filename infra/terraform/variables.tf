variable "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Kubernetes context to use"
  type        = string
  default     = "minikube"
}

variable "argocd_chart_version" {
  description = "Version of the ArgoCD Helm chart"
  type        = string
  default     = "5.51.6"
}

variable "argocd_nodeport" {
  description = "NodePort for ArgoCD server service"
  type        = number
  default     = 30080
}

variable "repo_url" {
  description = "Git repository URL for the root application"
  type        = string
  default     = "https://example.com/your/repo"
}

variable "repo_revision" {
  description = "Git revision (branch/tag) for the root application"
  type        = string
  default     = "main"
}
