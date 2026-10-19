#!/usr/bin/env bash
# Valida o chart sem cluster: lint, schema do Kubernetes (kubeconform) e
# casos que o chart precisa recusar. Deixa os manifests em render/ para o Trivy.
set -euo pipefail
cd "$(dirname "$0")/.."

CHART=charts/almoxarifado
VERSAO_K8S=1.34.11
VALORES=(--set existingSecret=almoxarifado-segredos --set api.image.tag=ci --set web.image.tag=ci)

ok() { printf '  \033[32mok\033[0m  %s\n' "$1"; }
falha() { printf '  \033[31mFALHOU\033[0m  %s\n' "$1"; exit 1; }

helm lint "$CHART" --strict "${VALORES[@]}"

rm -rf render && mkdir render
helm template almoxarifado "$CHART" -n almox "${VALORES[@]}" > render/almoxarifado.yaml
# CRDs (HTTPRoute) validadas pelo catálogo de schemas da comunidade
kubeconform -strict -summary -kubernetes-version "$VERSAO_K8S" \
  -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
  render/almoxarifado.yaml
ok "manifests válidos para o Kubernetes $VERSAO_K8S"

recusa() {
  local descricao="$1"; shift
  if helm template almoxarifado "$CHART" "$@" > /dev/null 2>&1; then falha "aceitou: $descricao"; fi
  ok "recusa $descricao"
}
recusa "imagem sem tag" --set existingSecret=s
recusa "tag latest" "${VALORES[@]}" --set api.image.tag=latest
recusa "instalação sem o Secret" --set api.image.tag=ci --set web.image.tag=ci
recusa "chave desconhecida nos values" "${VALORES[@]}" --set api.replicass=3
recusa "nome de banco inválido" "${VALORES[@]}" --set postgres.database=almox-prod

# Com o HPA ligado o Deployment não fixa réplicas (senão cada deploy desfaria a escala)
deployment_api() {
  helm template almoxarifado "$CHART" "${VALORES[@]}" "$@" --show-only templates/api.yaml \
    | sed -n '/^kind: Deployment$/,/^---$/p'
}
deployment_api | grep -q '^  name: almoxarifado-api$' || falha "Deployment da API não encontrado no template"
if deployment_api | grep -q '^  replicas:'; then falha "Deployment com réplicas fixas brigando com o HPA"; fi
deployment_api --set api.autoscaling.enabled=false --set api.replicas=3 | grep -q '^  replicas: 3$' \
  || falha "réplicas fixas sem o HPA"
ok "réplicas da API ficam com o HPA quando ele está ligado"
