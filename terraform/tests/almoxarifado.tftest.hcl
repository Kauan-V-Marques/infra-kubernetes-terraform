# Testa o módulo da aplicação: segredos, namespace e values passados ao chart

mock_provider "kubernetes" {}
mock_provider "helm" {}
mock_provider "random" {}

variables {
  chart             = "../charts/almoxarifado"
  hostname          = "almox.localhost"
  imagens           = { api = "almoxarifado-api", web = "almoxarifado-web" }
  versao            = "3f9c2ab"
  replicas          = { api_min = 2, api_max = 5, web = 2 }
  dados_de_exemplo  = true
  tamanho_banco     = "1Gi"
  gateway_name      = "publico"
  gateway_namespace = "gateway"
  label_acesso      = { "gateway.almox.dev/acesso" = "publico" }
}

run "segredos_e_values_do_chart" {
  # apply com providers simulados: os valores gerados (senhas) ficam conhecidos
  command = apply

  module {
    source = "./modules/almoxarifado"
  }

  assert {
    condition     = kubernetes_secret_v1.app.data["DATABASE_URL"] == "postgres://almox:${random_password.banco.result}@almoxarifado-postgres:5432/almox"
    error_message = "DATABASE_URL precisa usar a senha gerada e o Service do PostgreSQL"
  }

  assert {
    condition     = random_password.jwt.length >= 32 && random_password.banco.special == false
    error_message = "JWT_SECRET precisa de 32+ caracteres e a senha do banco não pode ter símbolos (vai numa URL)"
  }

  assert {
    condition     = yamldecode(helm_release.app.values[0]).existingSecret == kubernetes_secret_v1.app.metadata[0].name
    error_message = "O chart deve ler os segredos do Secret criado pelo Terraform"
  }

  assert {
    condition     = yamldecode(helm_release.app.values[0]).api.image.tag == "3f9c2ab" && yamldecode(helm_release.app.values[0]).web.image.tag == "3f9c2ab"
    error_message = "API e front devem subir na mesma versão"
  }

  assert {
    condition     = !strcontains(helm_release.app.values[0], random_password.banco.result) && !strcontains(helm_release.app.values[0], random_password.jwt.result)
    error_message = "Nenhum segredo pode ir nos values do Helm (eles ficam visíveis no release)"
  }
}

run "namespace_restrito_e_liberado_no_gateway" {
  command = plan

  module {
    source = "./modules/almoxarifado"
  }

  assert {
    condition     = kubernetes_namespace_v1.app.metadata[0].labels["pod-security.kubernetes.io/enforce"] == "restricted"
    error_message = "A aplicação deve rodar sob o Pod Security Standard restricted"
  }

  assert {
    condition     = kubernetes_namespace_v1.app.metadata[0].labels["gateway.almox.dev/acesso"] == "publico"
    error_message = "Sem o label de acesso o Gateway ignora as rotas da aplicação"
  }
}
