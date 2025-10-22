output "grafana_url" {
  value       = "http://localhost:32000"
  description = "Grafana NodePort URL"
}

output "argocd_url" {
  value       = "http://localhost:30080"
  description = "Argo CD Server NodePort URL"
}
