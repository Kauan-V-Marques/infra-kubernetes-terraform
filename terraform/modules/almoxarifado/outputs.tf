output "namespace" {
  description = "Namespace da aplicação"
  value       = kubernetes_namespace_v1.app.metadata[0].name
}

output "release" {
  description = "Nome do release Helm"
  value       = helm_release.app.name
}
