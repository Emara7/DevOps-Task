resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [
    yamlencode({
      global = {
        domain = "argocd.local"
      }
      
      server = {
        service = {
          type        = "NodePort"
          nodePortHttp = var.argocd_nodeport
        }
        resources = {
          requests = {
            cpu    = "50m"
            memory = "50Mi"
          }
          limits = {
            cpu    = "300m"
            memory = "200Mi"
          }
        }
      }
      
      controller = {
        resources = {
          requests = {
            cpu    = "50m"
            memory = "50Mi"
          }
          limits = {
            cpu    = "300m"
            memory = "200Mi"
          }
        }
      }
      
      repoServer = {
        resources = {
          requests = {
            cpu    = "50m"
            memory = "50Mi"
          }
          limits = {
            cpu    = "300m"
            memory = "200Mi"
          }
        }
      }
      
      configs = {
        params = {
          "server.insecure" = true
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.argocd]
}
