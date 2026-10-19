#!/usr/bin/env bash
# Teste de fumaça de fora do cluster, pelo mesmo caminho de um usuário:
#   máquina :443 -> kind -> Traefik (Gateway API) -> front / API -> PostgreSQL
# Depois força as situações que derrubam deploys mal feitos: rollout com tráfego,
# banco reiniciando e acesso de onde não deveria.
set -euo pipefail

HOST="${HOST:-almox.localhost}"
NS="${NS:-almox}"
RELEASE="${RELEASE:-almoxarifado}"
TMP="$(mktemp -d)"
CARGA_PID=""
trap '[ -n "$CARGA_PID" ] && kill "$CARGA_PID" 2>/dev/null; rm -rf "$TMP"' EXIT

ok() { printf '  \033[32mok\033[0m  %s\n' "$1"; }
falha() { printf '  \033[31mFALHOU\033[0m  %s\n' "$1"; exit 1; }
secao() { printf '\n\033[1m%s\033[0m\n' "$1"; }

# O certificado é autoassinado (gerado pelo Terraform): ele mesmo vira a CA confiável,
# então o curl confere a cadeia e o nome do host em vez de usar --insecure
kubectl -n gateway get secret tls-publico -o jsonpath='{.data.tls\.crt}' | base64 -d > "$TMP/ca.crt"
c() { curl -sS --cacert "$TMP/ca.crt" --resolve "$HOST:443:127.0.0.1" --resolve "$HOST:80:127.0.0.1" "$@"; }
json() { c -H 'Content-Type: application/json' "$@"; }

secao "Gateway e front"
read -r codigo destino < <(c -o /dev/null -w '%{http_code} %{redirect_url}\n' "http://$HOST/inventario")
if [ "$codigo" = 301 ] && [ "$destino" = "https://$HOST/inventario" ]; then ok "HTTP redireciona para HTTPS"; else falha "redirect: $codigo $destino"; fi

c -D "$TMP/cabecalhos" -o "$TMP/index.html" "https://$HOST/inventario"
grep -q '<div id="root">' "$TMP/index.html" && ok "rota do SPA cai no index.html" || falha "front não respondeu"
grep -qi '^x-content-type-options: nosniff' "$TMP/cabecalhos" && ok "cabeçalhos de segurança do nginx" || falha "sem cabeçalhos de segurança"
[ "$(c "https://$HOST/api/health" | jq -r .status)" = ok ] && ok "API responde em /api pelo mesmo endereço" || falha "API fora do ar"

secao "Autenticação"
json -c "$TMP/cookies" -D "$TMP/login-cabecalhos" -d '{"email":"capitao@almox.dev","password":"robotica123"}' \
  "https://$HOST/api/auth/login" > "$TMP/login.json"
TOKEN="$(jq -r .accessToken "$TMP/login.json")"
[ -n "$TOKEN" ] && [ "$TOKEN" != null ] && ok "login com os dados de exemplo" || falha "login: $(cat "$TMP/login.json")"

cookie="$(grep -i '^set-cookie: almox_refresh=' "$TMP/login-cabecalhos" | tr -d '\r')"
for atributo in HttpOnly Secure SameSite=Strict; do
  grep -qi "$atributo" <<< "$cookie" || falha "cookie de refresh sem $atributo"
done
ok "cookie de refresh HttpOnly, Secure e SameSite=Strict (HTTPS de ponta a ponta)"

novo="$(c -b "$TMP/cookies" -c "$TMP/cookies" -X POST "https://$HOST/api/auth/refresh" | jq -r .accessToken)"
[ -n "$novo" ] && [ "$novo" != null ] && ok "refresh pelo cookie gera um novo token" || falha "refresh"

SKU="FUMACA-$RANDOM"
status="$(json -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOKEN" \
  -d "{\"name\":\"Teste de fumaça\",\"sku\":\"$SKU\",\"category\":\"sensor\",\"quantity\":3,\"minQuantity\":1,\"location\":\"CI\"}" \
  "https://$HOST/api/components")"
[ "$status" = 201 ] && ok "capitã cadastra um componente ($SKU)" || falha "cadastro devolveu $status"

secao "Rollout sem downtime"
# Requisições sem parar enquanto todos os pods da API e do front são trocados
carga() {
  while :; do
    for caminho in /api/health /; do
      c -o /dev/null -w '%{http_code}\n' --max-time 5 "https://$HOST$caminho" >> "$TMP/status" 2>/dev/null || echo 000 >> "$TMP/status"
    done
    sleep 0.05
  done
}
carga &
CARGA_PID=$!
kubectl -n "$NS" rollout restart "deploy/$RELEASE-api" "deploy/$RELEASE-web" > /dev/null
kubectl -n "$NS" rollout status "deploy/$RELEASE-api" --timeout=300s > /dev/null
kubectl -n "$NS" rollout status "deploy/$RELEASE-web" --timeout=300s > /dev/null
# Os pods antigos ainda estão terminando (preStop + desligamento): a carga continua até sumirem
for _ in $(seq 60); do
  terminando="$(kubectl -n "$NS" get pods -l "app.kubernetes.io/instance=$RELEASE,app.kubernetes.io/component in (api,web)" \
    -o jsonpath='{range .items[*]}{.metadata.deletionTimestamp}{"\n"}{end}' | grep -c . || true)"
  [ "$terminando" = 0 ] && break
  sleep 2
done
sleep 3
kill "$CARGA_PID"; CARGA_PID=""
total="$(wc -l < "$TMP/status")"
erros="$(grep -vc '^200$' "$TMP/status" || true)"
[ "$erros" = 0 ] && ok "todas as réplicas trocadas, $total requisições e nenhuma falhou" \
  || falha "$erros de $total requisições falharam durante o rollout: $(sort "$TMP/status" | uniq -c | tr '\n' ' ')"

secao "Banco reiniciando"
kubectl -n "$NS" delete pod "$RELEASE-postgres-0" --wait=true > /dev/null
kubectl -n "$NS" wait --for=condition=Ready "pod/$RELEASE-postgres-0" --timeout=180s > /dev/null
ok "StatefulSet recriou o pod do PostgreSQL"

encontrados=0
for _ in $(seq 30); do
  encontrados="$(c -H "Authorization: Bearer $TOKEN" "https://$HOST/api/components?search=$SKU" | jq 'length' 2>/dev/null || echo 0)"
  [ "$encontrados" = 1 ] && break
  sleep 2
done
[ "$encontrados" = 1 ] && ok "componente cadastrado antes continua lá (volume persistente)" || falha "dado perdido após reiniciar o banco"

reinicios="$(kubectl -n "$NS" get pods -l "app.kubernetes.io/component=api" \
  -o jsonpath='{range .items[*]}{.status.containerStatuses[0].restartCount}{"\n"}{end}' | sort -n | tail -1)"
[ "$reinicios" = 0 ] && ok "nenhum pod da API reiniciou com a queda do banco" || falha "a API reiniciou $reinicios vez(es)"

secao "Isolamento de rede"
# Um pod de outro namespace tenta falar direto com a API e com o banco
for alvo in "$RELEASE-api.$NS:3333" "$RELEASE-postgres.$NS:5432"; do
  codigo="$(kubectl run "netpol-$RANDOM" -n default --rm -i --quiet --restart=Never --image=curlimages/curl:8.22.0 \
    --command -- sh -c "curl -s -o /dev/null --connect-timeout 3 http://$alvo/; echo \$?" | tail -1 | tr -d '\r')"
  if [ "$codigo" = 28 ] || [ "$codigo" = 7 ]; then ok "$alvo bloqueado para quem está fora (curl $codigo)"; else falha "$alvo acessível de outro namespace (curl $codigo)"; fi
done

secao "Autoscaling"
for _ in $(seq 40); do
  cpu="$(kubectl -n "$NS" get hpa "$RELEASE-api" -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}' 2>/dev/null || true)"
  [ -n "$cpu" ] && break
  sleep 5
done
[ -n "$cpu" ] && ok "HPA lendo a CPU da API pelo metrics-server (${cpu}% do pedido)" || falha "HPA sem métricas"

printf '\n\033[32mTudo certo.\033[0m\n'
