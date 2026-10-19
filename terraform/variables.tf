variable "kubeconfig" {
  description = "Arquivo kubeconfig do cluster"
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Contexto do kubeconfig (o kind cria kind-<nome do cluster>)"
  type        = string
}

variable "hostname" {
  description = "Endereço público da aplicação"
  type        = string
}

variable "tls_autoassinado" {
  description = "Gera um certificado autoassinado para o Gateway (no lugar do cert-manager)"
  type        = bool
  default     = false
}

variable "gateway_node_ports" {
  description = "Portas fixas do Traefik nos nós (o kind mapeia 80 e 443 da máquina para elas). null = LoadBalancer"
  type = object({
    http  = number
    https = number
  })
  default = null
}

variable "metrics_server_inseguro" {
  description = "Aceita o certificado autoassinado do kubelet (necessário no kind)"
  type        = bool
  default     = false
}

variable "imagens" {
  description = "Repositório das imagens da aplicação"
  type = object({
    api = string
    web = string
  })
}

variable "versao" {
  description = "Tag das imagens (imutável: commit ou versão, nunca latest)"
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$", var.versao)) && var.versao != "latest"
    error_message = "Use uma tag imutável (ex.: 1.0.0 ou o hash do commit), não \"latest\"."
  }
}

variable "replicas" {
  description = "Réplicas mínimas e máximas da API (HPA) e réplicas do front"
  type = object({
    api_min = number
    api_max = number
    web     = number
  })
  default = { api_min = 2, api_max = 5, web = 2 }

  validation {
    condition     = var.replicas.api_min >= 2 && var.replicas.api_max >= var.replicas.api_min
    error_message = "A API precisa de pelo menos 2 réplicas (o PodDisruptionBudget mantém 1 no ar) e api_max >= api_min."
  }
}

variable "dados_de_exemplo" {
  description = "Carrega a equipe de exemplo com o banco vazio (só em ambientes de teste)"
  type        = bool
  default     = false
}

variable "tamanho_banco" {
  description = "Tamanho do volume do PostgreSQL"
  type        = string
  default     = "1Gi"
}
