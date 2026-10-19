# terraform test: roda sem cluster nenhum, com os providers simulados

mock_provider "kubernetes" {}
mock_provider "helm" {}
mock_provider "random" {}
mock_provider "tls" {}

variables {
  kube_context = "teste"
  hostname     = "almox.teste"
  imagens      = { api = "almoxarifado-api", web = "almoxarifado-web" }
  versao       = "3f9c2ab"
}

run "configuracao_valida_passa" {
  command = plan
}

run "tag_latest_e_recusada" {
  command = plan

  variables {
    versao = "latest"
  }

  expect_failures = [var.versao]
}

run "tag_com_caractere_invalido_e_recusada" {
  command = plan

  variables {
    versao = "v1 beta"
  }

  expect_failures = [var.versao]
}

run "api_com_uma_replica_e_recusada" {
  command = plan

  variables {
    replicas = { api_min = 1, api_max = 3, web = 2 }
  }

  expect_failures = [var.replicas]
}

run "maximo_menor_que_minimo_e_recusado" {
  command = plan

  variables {
    replicas = { api_min = 4, api_max = 2, web = 2 }
  }

  expect_failures = [var.replicas]
}
