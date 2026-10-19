output "gateway_name" {
  description = "Nome do Gateway compartilhado"
  value       = local.gateway_name
  # Só existe depois que o Traefik (que cria o Gateway) estiver pronto
  depends_on = [helm_release.traefik]
}

output "gateway_namespace" {
  description = "Namespace do Gateway"
  value       = kubernetes_namespace_v1.gateway.metadata[0].name
}

output "label_acesso" {
  description = "Label que um namespace precisa ter para usar o Gateway"
  value       = local.label_acesso
}
