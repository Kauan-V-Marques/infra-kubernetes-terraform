output "url" {
  description = "Endereço da aplicação"
  value       = "https://${var.hostname}"
}

output "namespace" {
  description = "Namespace da aplicação"
  value       = module.almoxarifado.namespace
}

output "release" {
  description = "Release do Helm (para helm status / helm test)"
  value       = module.almoxarifado.release
}
