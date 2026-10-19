variable "hostnames" {
  description = "Nomes atendidos pelo Gateway (entram no certificado autoassinado)"
  type        = list(string)

  validation {
    condition     = length(var.hostnames) > 0
    error_message = "Informe pelo menos um hostname."
  }
}

variable "tls_autoassinado" {
  description = "Gera o certificado do Gateway aqui (senão, outro componente cria o Secret tls-publico)"
  type        = bool
}

variable "node_ports" {
  description = "Portas fixas nos nós para HTTP e HTTPS; null = Service LoadBalancer"
  type = object({
    http  = number
    https = number
  })
  default = null
}

variable "metrics_server_inseguro" {
  description = "Aceita o certificado autoassinado do kubelet (kind)"
  type        = bool
  default     = false
}

variable "versao_traefik" {
  description = "Versão do chart do Traefik"
  type        = string
  default     = "41.6.0"
}

variable "versao_metrics_server" {
  description = "Versão do chart do metrics-server"
  type        = string
  default     = "3.14.0"
}
