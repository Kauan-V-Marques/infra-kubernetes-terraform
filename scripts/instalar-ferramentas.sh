#!/usr/bin/env bash
# Instala as ferramentas em versões fixas (Linux amd64), conferindo o SHA-256 de cada download
# contra o arquivo de checksums publicado no release. Nada de "curl | sh".
#
# Uso: scripts/instalar-ferramentas.sh [ferramenta...]   (sem argumentos = todas)
set -euo pipefail

TERRAFORM=1.16.6
HELM=v3.22.1
KIND=v0.33.0
KUBECTL=v1.34.11
KUBECONFORM=v0.8.0
TRIVY=0.75.0

DESTINO="${DESTINO:-$HOME/.local/bin}"
mkdir -p "$DESTINO"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"

baixar() { curl -fsSLO "$1"; }

instalar() {
  case "$1" in
    terraform)
      baixar "https://releases.hashicorp.com/terraform/${TERRAFORM}/terraform_${TERRAFORM}_linux_amd64.zip"
      baixar "https://releases.hashicorp.com/terraform/${TERRAFORM}/terraform_${TERRAFORM}_SHA256SUMS"
      grep "_linux_amd64.zip" "terraform_${TERRAFORM}_SHA256SUMS" | sha256sum -c
      unzip -oq "terraform_${TERRAFORM}_linux_amd64.zip" terraform -d "$DESTINO" ;;
    helm)
      baixar "https://get.helm.sh/helm-${HELM}-linux-amd64.tar.gz"
      baixar "https://get.helm.sh/helm-${HELM}-linux-amd64.tar.gz.sha256sum"
      sha256sum -c "helm-${HELM}-linux-amd64.tar.gz.sha256sum"
      tar -xzf "helm-${HELM}-linux-amd64.tar.gz" --strip-components=1 -C "$DESTINO" linux-amd64/helm ;;
    kind)
      baixar "https://github.com/kubernetes-sigs/kind/releases/download/${KIND}/kind-linux-amd64"
      baixar "https://github.com/kubernetes-sigs/kind/releases/download/${KIND}/kind-linux-amd64.sha256sum"
      sha256sum -c kind-linux-amd64.sha256sum
      install -m 0755 kind-linux-amd64 "$DESTINO/kind" ;;
    kubectl)
      baixar "https://dl.k8s.io/release/${KUBECTL}/bin/linux/amd64/kubectl"
      baixar "https://dl.k8s.io/release/${KUBECTL}/bin/linux/amd64/kubectl.sha256"
      echo "$(cat kubectl.sha256)  kubectl" | sha256sum -c
      install -m 0755 kubectl "$DESTINO/kubectl" ;;
    kubeconform)
      baixar "https://github.com/yannh/kubeconform/releases/download/${KUBECONFORM}/kubeconform-linux-amd64.tar.gz"
      baixar "https://github.com/yannh/kubeconform/releases/download/${KUBECONFORM}/CHECKSUMS"
      grep "kubeconform-linux-amd64.tar.gz" CHECKSUMS | sha256sum -c
      tar -xzf kubeconform-linux-amd64.tar.gz -C "$DESTINO" kubeconform ;;
    trivy)
      baixar "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY}/trivy_${TRIVY}_Linux-64bit.tar.gz"
      baixar "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY}/trivy_${TRIVY}_checksums.txt"
      grep "_Linux-64bit.tar.gz" "trivy_${TRIVY}_checksums.txt" | sha256sum -c
      tar -xzf "trivy_${TRIVY}_Linux-64bit.tar.gz" -C "$DESTINO" trivy ;;
    *)
      echo "Ferramenta desconhecida: $1" >&2
      exit 1 ;;
  esac
}

ferramentas=("$@")
[ ${#ferramentas[@]} -eq 0 ] && ferramentas=(terraform helm kind kubectl kubeconform trivy)
for ferramenta in "${ferramentas[@]}"; do instalar "$ferramenta"; done

if [ -n "${GITHUB_PATH:-}" ]; then echo "$DESTINO" >> "$GITHUB_PATH"; fi
echo "Instalado em $DESTINO: ${ferramentas[*]}"
