# Plataforma: o que o cluster oferece para qualquer aplicação (Gateway, métricas, TLS)
module "plataforma" {
  source = "./modules/plataforma"

  hostnames               = [var.hostname]
  tls_autoassinado        = var.tls_autoassinado
  node_ports              = var.gateway_node_ports
  metrics_server_inseguro = var.metrics_server_inseguro
}

# Aplicação: namespace isolado, segredos gerados aqui e o chart Helm do almoxarifado
module "almoxarifado" {
  source = "./modules/almoxarifado"

  hostname          = var.hostname
  chart             = "${path.module}/../charts/almoxarifado"
  imagens           = var.imagens
  versao            = var.versao
  replicas          = var.replicas
  dados_de_exemplo  = var.dados_de_exemplo
  tamanho_banco     = var.tamanho_banco
  gateway_name      = module.plataforma.gateway_name
  gateway_namespace = module.plataforma.gateway_namespace
  label_acesso      = module.plataforma.label_acesso
}
