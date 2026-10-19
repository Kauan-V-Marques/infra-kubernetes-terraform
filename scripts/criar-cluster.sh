#!/usr/bin/env bash
# Cria o cluster kind e instala as CRDs da Gateway API.
# As CRDs são parte do cluster (como num EKS/GKE), por isso ficam fora do Terraform.
set -euo pipefail
cd "$(dirname "$0")/.."

GATEWAY_API_VERSAO="${GATEWAY_API_VERSAO:-v1.6.1}"

if kind get clusters 2>/dev/null | grep -qx almox; then
  echo "Cluster almox já existe"
else
  kind create cluster --config kind/cluster.yaml --wait 180s
fi

kubectl apply --server-side \
  -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSAO}/standard-install.yaml"
kubectl wait --for condition=Established --timeout=60s \
  crd/gatewayclasses.gateway.networking.k8s.io \
  crd/gateways.gateway.networking.k8s.io \
  crd/httproutes.gateway.networking.k8s.io

kubectl get nodes -o wide
