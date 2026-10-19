locals {
  # Release com o mesmo nome do chart: os recursos ficam "almoxarifado-api", "almoxarifado-postgres"...
  release       = "almoxarifado"
  host_banco    = "${local.release}-postgres"
  usuario_banco = "almox"
  nome_banco    = "almox"
}

resource "kubernetes_namespace_v1" "app" {
  metadata {
    name = var.namespace
    labels = merge(var.label_acesso, {
      # Pod Security Admission: pods com root, privilégios ou sem seccomp são recusados
      "pod-security.kubernetes.io/enforce" = "restricted"
      "pod-security.kubernetes.io/warn"    = "restricted"
    })
  }
}

# Os segredos nascem aqui e vão direto para um Secret: nunca passam pelo Git nem pelos values
resource "random_password" "banco" {
  length  = 32
  special = false
}

resource "random_password" "jwt" {
  length  = 64
  special = false
}

resource "kubernetes_secret_v1" "app" {
  metadata {
    name      = "${local.release}-segredos"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }
  data = {
    POSTGRES_PASSWORD = random_password.banco.result
    DATABASE_URL      = "postgres://${local.usuario_banco}:${random_password.banco.result}@${local.host_banco}:5432/${local.nome_banco}"
    JWT_SECRET        = random_password.jwt.result
  }
}

resource "helm_release" "app" {
  name        = local.release
  namespace   = kubernetes_namespace_v1.app.metadata[0].name
  chart       = var.chart
  wait        = true
  timeout     = 600
  max_history = 5

  values = [yamlencode({
    hostname       = var.hostname
    existingSecret = kubernetes_secret_v1.app.metadata[0].name
    api = {
      image    = { repository = var.imagens.api, tag = var.versao }
      seedDemo = var.dados_de_exemplo
      autoscaling = {
        enabled     = true
        minReplicas = var.replicas.api_min
        maxReplicas = var.replicas.api_max
      }
    }
    web = {
      image    = { repository = var.imagens.web, tag = var.versao }
      replicas = var.replicas.web
    }
    postgres = {
      database = local.nome_banco
      user     = local.usuario_banco
      storage  = { size = var.tamanho_banco }
    }
    gateway = {
      name      = var.gateway_name
      namespace = var.gateway_namespace
    }
    networkPolicy = { gatewayNamespace = var.gateway_namespace }
  })]
}
