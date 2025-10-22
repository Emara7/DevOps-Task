variable "kubeconfig" {
  description = "Path to kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Kubeconfig context name"
  type        = string
  default     = "minikube"
}

variable "minikube_profile" {
  description = "Minikube profile name"
  type        = string
  default     = "minikube"
}

variable "minikube_driver" {
  description = "Minikube driver (docker, none, virtualbox, etc.)"
  type        = string
  default     = "docker"
}

variable "minikube_cpus" {
  description = "Minikube vCPUs"
  type        = number
  default     = 2
}

variable "minikube_memory" {
  description = "Minikube memory in MB"
  type        = number
  default     = 4096
}

variable "kubernetes_version" {
  description = "Kubernetes version for Minikube"
  type        = string
  default     = "v1.29.6"
}

variable "argocd_namespace" {
  description = "Namespace for Argo CD"
  type        = string
  default     = "argocd"
}

variable "observability_namespace" {
  description = "Namespace for observability stack"
  type        = string
  default     = "observability"
}

variable "apps_namespace" {
  description = "Namespace for sample applications"
  type        = string
  default     = "apps"
}

variable "argocd_chart_version" {
  type        = string
  default     = "6.7.18"
}

variable "argocd_apps_chart_version" {
  type        = string
  default     = "1.6.2"
}

variable "loki_chart_version" {
  type        = string
  default     = "6.6.4"
}

variable "grafana_chart_version" {
  type        = string
  default     = "8.4.2"
}

variable "otel_collector_chart_version" {
  type        = string
  default     = "0.100.1"
}

variable "github_webhook_secret" {
  description = "Secret used by Argo CD GitHub webhook validation"
  type        = string
  sensitive   = true
}

variable "app_repo_url" {
  description = "Git repository URL that contains the sample app Helm chart"
  type        = string
}

variable "app_repo_path" {
  description = "Path in the repo to the Helm chart for the sample app"
  type        = string
  default     = "charts/sample-app"
}

variable "sample_app_name" {
  description = "Argo CD Application name"
  type        = string
  default     = "sample-app"
}
