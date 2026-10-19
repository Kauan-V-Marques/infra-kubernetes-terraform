locals {
  gateway_name    = "publico"
  tls_secret_name = "tls-publico"
  # Só namespaces com este label podem pendurar rotas no Gateway
  label_acesso = { "gateway.almox.dev/acesso" = local.gateway_name }

  listener_comum = {
    namespacePolicy = {
      from     = "Selector"
      selector = { matchLabels = local.label_acesso }
    }
  }
}

resource "kubernetes_namespace_v1" "gateway" {
  metadata {
    name = "gateway"
    labels = {
      "pod-security.kubernetes.io/enforce" = "restricted"
      "pod-security.kubernetes.io/warn"    = "restricted"
    }
  }
}

# Certificado autoassinado para o Gateway (kind e CI). Em produção quem preenche
# o mesmo Secret é o cert-manager, e este bloco fica desligado.
resource "tls_private_key" "gateway" {
  count = var.tls_autoassinado ? 1 : 0

  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "gateway" {
  count = var.tls_autoassinado ? 1 : 0

  private_key_pem       = tls_private_key.gateway[0].private_key_pem
  dns_names             = var.hostnames
  validity_period_hours = 24 * 90
  early_renewal_hours   = 24 * 15
  allowed_uses          = ["digital_signature", "key_encipherment", "server_auth"]

  subject {
    common_name  = var.hostnames[0]
    organization = "Almoxarifado (teste)"
  }
}

resource "kubernetes_secret_v1" "tls" {
  count = var.tls_autoassinado ? 1 : 0

  metadata {
    name      = local.tls_secret_name
    namespace = kubernetes_namespace_v1.gateway.metadata[0].name
  }
  type = "kubernetes.io/tls"
  data = {
    "tls.crt" = tls_self_signed_cert.gateway[0].cert_pem
    "tls.key" = tls_private_key.gateway[0].private_key_pem
  }
}

# Traefik como implementação da Gateway API (as CRDs vêm no bootstrap do cluster)
resource "helm_release" "traefik" {
  name       = "traefik"
  namespace  = kubernetes_namespace_v1.gateway.metadata[0].name
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = var.versao_traefik
  # As CRDs próprias do Traefik (IngressRoute etc.) não são usadas: só Gateway API
  skip_crds   = true
  wait        = true
  timeout     = 300
  max_history = 5

  values = [yamlencode({
    providers = {
      kubernetesGateway = { enabled = true }
      kubernetesIngress = { enabled = false }
      kubernetesCRD     = { enabled = false }
    }
    ingressClass = { enabled = false }
    ingressRoute = { dashboard = { enabled = false } }
    gatewayClass = { enabled = true, name = "traefik" }
    gateway = {
      enabled = true
      name    = local.gateway_name
      listeners = {
        web = merge(local.listener_comum, { port = 8000, protocol = "HTTP" })
        websecure = merge(local.listener_comum, {
          port            = 8443
          protocol        = "HTTPS"
          certificateRefs = [{ name = local.tls_secret_name }]
        })
      }
    }
    service = { type = var.node_ports == null ? "LoadBalancer" : "NodePort" }
    ports = {
      web       = { nodePort = try(var.node_ports.http, null) }
      websecure = { nodePort = try(var.node_ports.https, null) }
    }
    resources = {
      requests = { cpu = "50m", memory = "64Mi" }
      limits   = { cpu = "500m", memory = "256Mi" }
    }
  })]

  depends_on = [kubernetes_secret_v1.tls]
}

# Métricas de CPU e memória dos pods: é delas que o HPA da API depende
resource "helm_release" "metrics_server" {
  name        = "metrics-server"
  namespace   = "kube-system"
  repository  = "https://kubernetes-sigs.github.io/metrics-server/"
  chart       = "metrics-server"
  version     = var.versao_metrics_server
  wait        = true
  timeout     = 300
  max_history = 5

  values = [yamlencode({
    args = var.metrics_server_inseguro ? ["--kubelet-insecure-tls"] : []
  })]
}
