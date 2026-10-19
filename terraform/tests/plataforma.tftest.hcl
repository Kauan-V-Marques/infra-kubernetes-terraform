# Testa o módulo de plataforma isolado: como o Gateway é exposto em cada ambiente

mock_provider "kubernetes" {}
mock_provider "helm" {}
mock_provider "tls" {}

run "kind_usa_nodeport_fixo_e_certificado_proprio" {
  command = plan

  module {
    source = "./modules/plataforma"
  }

  variables {
    hostnames        = ["almox.localhost"]
    tls_autoassinado = true
    node_ports       = { http = 30080, https = 30443 }
  }

  assert {
    condition     = yamldecode(helm_release.traefik.values[0]).service.type == "NodePort"
    error_message = "No kind o Traefik precisa de NodePort (o kind mapeia 80/443 para ele)"
  }

  assert {
    condition     = yamldecode(helm_release.traefik.values[0]).ports.websecure.nodePort == 30443
    error_message = "Porta HTTPS do nó diferente da mapeada no kind/cluster.yaml"
  }

  assert {
    condition     = length(kubernetes_secret_v1.tls) == 1 && tls_self_signed_cert.gateway[0].dns_names == tolist(["almox.localhost"])
    error_message = "O certificado autoassinado deve cobrir o hostname da aplicação"
  }
}

run "producao_usa_loadbalancer_e_certificado_externo" {
  command = plan

  module {
    source = "./modules/plataforma"
  }

  variables {
    hostnames        = ["almox.exemplo.com.br"]
    tls_autoassinado = false
  }

  assert {
    condition     = yamldecode(helm_release.traefik.values[0]).service.type == "LoadBalancer"
    error_message = "Sem node_ports o Traefik deve usar um LoadBalancer"
  }

  assert {
    condition     = length(kubernetes_secret_v1.tls) == 0 && length(tls_private_key.gateway) == 0
    error_message = "Com certificado externo (cert-manager) nada de chave gerada pelo Terraform"
  }
}

run "gateway_so_aceita_rotas_de_namespaces_liberados" {
  command = plan

  module {
    source = "./modules/plataforma"
  }

  variables {
    hostnames        = ["almox.localhost"]
    tls_autoassinado = true
  }

  assert {
    condition = alltrue([
      for listener in values(yamldecode(helm_release.traefik.values[0]).gateway.listeners) :
      listener.namespacePolicy.from == "Selector"
    ])
    error_message = "Os listeners não podem aceitar rotas de qualquer namespace"
  }

  assert {
    condition     = kubernetes_namespace_v1.gateway.metadata[0].labels["pod-security.kubernetes.io/enforce"] == "restricted"
    error_message = "O namespace do Gateway deve aplicar o Pod Security Standard restricted"
  }
}
