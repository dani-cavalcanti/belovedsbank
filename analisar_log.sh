#!/bin/bash

# Este script executa as requisições em sequência, salvando a resposta JSON completa
# da API de callback e o arquivo Markdown final para análise.

# Configura o script para sair imediatamente se um comando falhar
set -e

# === Função de erro ===
# Exibe uma mensagem de erro no stderr e encerra o script.
erro() { echo "Erro: $1" >&2; exit 1; }

# === Verificações de requisitos ===
command -v jq >/dev/null 2>&1 || erro "O utilitário 'jq' não está instalado. Instale com: sudo apt-get install jq"
[ -f "error.log" ] || erro "Arquivo 'error.log' não encontrado no diretório atual."

# === Gera o access token ===
TOKEN_URL="https://idm.stackspot.com/${REALM:-stackspot-freemium}/oidc/oauth/token"
ACCESS_TOKEN=$(curl -s --location --request POST "$TOKEN_URL" \
  --header 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode "client_id=${CLIENT_ID}" \
  --data-urlencode 'grant_type=client_credentials' \
  --data-urlencode "client_secret=${CLIENT_SECRET}" | jq -r .access_token)

[ "$ACCESS_TOKEN" == "null" ] || [ -z "$ACCESS_TOKEN" ] && erro "Erro ao obter access token!"

# === Serializa o log de erro para JSON e chama a API (create-execution) ===
JSON=$(jq -n --arg logs_erro "$(cat error.log)" '{input_data: $logs_erro}')
RESPONSE=$(curl -s -X POST "https://genai-code-buddy-api.stackspot.com/v1/quick-commands/create-execution/analisar-logs-da-pipeline" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$JSON")

# Extrai o execution_id
EXECUTION_ID=$(echo "$RESPONSE" | tr -d '"' | jq -r .execution_id)
[ -z "$EXECUTION_ID" ] || [ "$EXECUTION_ID" == "null" ] && erro "execution_id não encontrado na resposta do Quick Command!"

# === Loop até status COMPLETED ===
# Um loop robusto para aguardar a resposta da API
MAX_TRIES=180
SLEEP_TIME=5
TRIES=0

echo "Aguardando o resultado do Quick Command. Isso pode levar alguns segundos..."
while [ "$TRIES" -lt "$MAX_TRIES" ]; do
  RESULT_RESPONSE=$(curl -s -X GET "https://genai-code-buddy-api.stackspot.com/v1/quick-commands/callback/$EXECUTION_ID" \
    -H "Authorization: Bearer $ACCESS_TOKEN")

  # Salva o JSON completo em um arquivo para sua análise
  echo "$RESULT_RESPONSE" > "resposta_completa.json"

  # Verifica se a resposta não está vazia e é um JSON válido
  if [ -z "$RESULT_RESPONSE" ] || ! echo "$RESULT_RESPONSE" | jq . >/dev/null 2>&1; then
    echo "Aguardando JSON válido..."
    TRIES=$((TRIES + 1))
    sleep "$SLEEP_TIME"
    continue
  fi

  # Extrai e verifica o status
  STATUS=$(echo "$RESULT_RESPONSE" | jq -r .status)

  if [ "$STATUS" == "COMPLETED" ]; then
    echo "Status COMPLETED. Extraindo resultado..."
    break
  fi

  TRIES=$((TRIES + 1))
  sleep "$SLEEP_TIME"
done

# Verifica se o loop excedeu o limite de tentativas.
if [ "$TRIES" -eq "$MAX_TRIES" ]; then
  erro "O tempo limite de espera foi atingido. O status não se tornou COMPLETED."
fi

# === Extrai a resposta final e salva em Markdown ===
echo "$RESULT_RESPONSE" | jq -r '.result.answer' > resposta_lys.md || erro "Falha ao gerar o arquivo Markdown."

echo "Análise concluída. O resultado foi salvo em 'resposta_lys.md' e o JSON completo em 'resposta_completa.json'."
