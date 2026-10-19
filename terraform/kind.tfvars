# Cluster local (kind) e CI: certificado autoassinado, portas fixas e dados de exemplo
kube_context = "kind-almox"
hostname     = "almox.localhost"

tls_autoassinado        = true
metrics_server_inseguro = true
gateway_node_ports      = { http = 30080, https = 30443 }

# Imagens construídas na máquina e carregadas no kind (kind load docker-image)
imagens = { api = "almoxarifado-api", web = "almoxarifado-web" }
versao  = "local"

dados_de_exemplo = true
