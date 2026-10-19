#!/usr/bin/env bash
# Constrói as imagens da API e do front a partir do repositório almoxarifado-robotica
# e carrega no kind (sem registry). A tag é o commit da aplicação.
#
# Uso: scripts/construir-imagens.sh <pasta do almoxarifado-robotica>
set -euo pipefail

APP="${1:?informe a pasta do almoxarifado-robotica}"
TAG="${TAG:-$(git -C "$APP" rev-parse --short=12 HEAD)}"

docker build -f "$APP/apps/api/Dockerfile" -t "almoxarifado-api:$TAG" "$APP"
docker build -f "$APP/apps/web/Dockerfile" -t "almoxarifado-web:$TAG" "$APP"
kind load docker-image --name almox "almoxarifado-api:$TAG" "almoxarifado-web:$TAG"

echo "Imagens carregadas no kind com a tag $TAG"
if [ -n "${GITHUB_ENV:-}" ]; then echo "TAG=$TAG" >> "$GITHUB_ENV"; fi
