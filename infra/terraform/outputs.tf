output "namespaces" {
  description = "Created namespaces"
  value = {
    argocd        = kubernetes_namespace.argocd.metadata[0].name
    observability = kubernetes_namespace.observability.metadata[0].name
    apps          = kubernetes_namespace.apps.metadata[0].name
  }
}

output "argocd_release" {
  description = "ArgoCD Helm release information"
  value = {
    name      = helm_release.argocd.name
    namespace = helm_release.argocd.namespace
    version   = helm_release.argocd.version
  }
}

output "argocd_access_info" {
  description = "ArgoCD access information"
  value = {
    nodeport = var.argocd_nodeport
    url      = "http://$(minikube ip):${var.argocd_nodeport}"
    note     = "Get Minikube IP with: minikube ip"
  }
}
