terraform {
  required_version = ">= 1.4.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.28.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12.1"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.2"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.5.1"
    }
  }
}

provider "kubernetes" {
  config_path    = var.kubeconfig
  config_context = var.kube_context
}

provider "helm" {
  # Ensure Helm talks to the same kubeconfig/context as the Kubernetes provider
  kubernetes {
    config_path    = var.kubeconfig
    config_context = var.kube_context
  }
}

# Ensure Minikube is up using a local-exec calling our script when requested
resource "null_resource" "minikube" {
  triggers = {
    profile = var.minikube_profile
    k8s     = var.kubernetes_version
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/../scripts/setup_minikube.sh"
    environment = {
      PROFILE     = var.minikube_profile
      K8S_VERSION = var.kubernetes_version
      DRIVER      = var.minikube_driver
      CPUS        = var.minikube_cpus
      MEMORY_MB   = var.minikube_memory
    }
  }
}

# Namespaces
resource "kubernetes_namespace" "argocd" {
  metadata { name = var.argocd_namespace }
  depends_on = [null_resource.minikube]
}

resource "kubernetes_namespace" "observability" {
  metadata { name = var.observability_namespace }
  depends_on = [null_resource.minikube]
}

resource "kubernetes_namespace" "apps" {
  metadata { name = var.apps_namespace }
  depends_on = [null_resource.minikube]
}

# Argo CD via Helm
resource "helm_release" "argocd" {
  name       = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [file("${path.module}/../helm-values/argocd-values.yaml")]

  # Wire GitHub webhook secret into argocd-secret so /api/webhook validates signatures
  set_sensitive = [
    {
      # Escape dots so the key in the secret is literally "webhook.github.secret"
      name  = "configs.secret.extra.webhook\\.github\\.secret"
      value = var.github_webhook_secret
    }
  ]

  depends_on = [kubernetes_namespace.argocd]
}

# Grafana Loki stack (loki + promtail or loki-distributed). We'll use simple Loki + promtail and Grafana standalone
resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  version    = var.loki_chart_version
  namespace  = kubernetes_namespace.observability.metadata[0].name

  values = [file("${path.module}/../helm-values/loki-stack-values.yaml")]

  depends_on = [kubernetes_namespace.observability]
}

resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = var.grafana_chart_version
  namespace  = kubernetes_namespace.observability.metadata[0].name

  values = [file("${path.module}/../helm-values/grafana-values.yaml")]

  depends_on = [kubernetes_namespace.observability]
}

# OpenTelemetry Collector
resource "helm_release" "otel_collector" {
  name       = "otel-collector"
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-collector"
  version    = var.otel_collector_chart_version
  namespace  = kubernetes_namespace.observability.metadata[0].name

  values = [file("${path.module}/../helm-values/otel-collector-values.yaml")]

  depends_on = [kubernetes_namespace.observability, helm_release.loki]
}

## Manage Argo CD Applications using the official argocd-apps chart
resource "helm_release" "argocd_apps" {
  name       = "argocd-apps"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.argocd_apps_chart_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [templatefile("${path.module}/../helm-values/argocd-apps-values.yaml", {
    app_name         = var.sample_app_name,
    repo_url         = var.app_repo_url,
    repo_path        = var.app_repo_path,
    destination_ns   = kubernetes_namespace.apps.metadata[0].name,
    destination_name = var.kube_context
  })]

  depends_on = [helm_release.argocd, kubernetes_namespace.apps]
}
