resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      app = "platform"
    }
  }
}

resource "kubernetes_namespace" "observability" {
  metadata {
    name = "observability"
    labels = {
      app = "platform"
    }
  }
}

resource "kubernetes_namespace" "apps" {
  metadata {
    name = "apps"
    labels = {
      app = "platform"
    }
  }
}
