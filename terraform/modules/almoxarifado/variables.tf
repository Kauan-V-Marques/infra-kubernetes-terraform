variable "namespace" {
  description = "Namespace da aplicação"
  type        = string
  default     = "almox"
}

variable "chart" {
  description = "Caminho (ou referência) do chart Helm"
  type        = string
}

variable "hostname" {
  description = "Endereço público"
  type        = string
}

variable "imagens" {
  description = "Repositório das imagens da API e do front"
  type = object({
    api = string
    web = string
  })
}

variable "versao" {
  description = "Tag das imagens"
  type        = string
}

variable "replicas" {
  description = "Réplicas da API (mínimo e máximo do HPA) e do front"
  type = object({
    api_min = number
    api_max = number
    web     = number
  })
}

variable "dados_de_exemplo" {
  description = "Carrega a equipe de exemplo com o banco vazio"
  type        = bool
}

variable "tamanho_banco" {
  description = "Tamanho do volume do PostgreSQL"
  type        = string
}

variable "gateway_name" {
  description = "Gateway onde as rotas se penduram"
  type        = string
}

variable "gateway_namespace" {
  description = "Namespace do Gateway"
  type        = string
}

variable "label_acesso" {
  description = "Label que libera o namespace no Gateway"
  type        = map(string)
}
