#!/bin/bash

# === CONFIGURAÇÕES ===
CLIENT_ID="${CLIENT_ID}"
CLIENT_SECRET="${CLIENT_SECRET}"
REALM="${REALM:-stackspot-freemium}"
TOKEN_URL="https://idm.stackspot.com/${REALM}/oidc/oauth/token"
QUICK_COMMAND_SLUG="analisar-logs-da-pipeline"
QUICK_COMMAND_URL="https://genai-code-buddy-api.stackspot.com/v1/quick-commands/create-execution/${QUICK_COMMAND_SLUG}"

# === Função de erro ===
erro() {
  echo "Erro: $1"
  exit 1
}

# === Verificações de requisitos ===
command -v jq >/dev/null 2>&1 || erro "O utilitário 'jq' não está instalado. Instale com: sudo apt-get install jq"

# === Verifica se o arquivo de log existe ===
[ -f "error.log" ] || erro "Arquivo 'error.log' não encontrado no diretório atual."

# === 1. GERAR ACCESS TOKEN ===
ACCESS_TOKEN=$(curl -s --location --request POST "$TOKEN_URL" \
  --header 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode "client_id=${CLIENT_ID}" \
  --data-urlencode 'grant_type=client_credentials' \
  --data-urlencode "client_secret=${CLIENT_SECRET}" | jq -r .access_token)

if [ "$ACCESS_TOKEN" == "null" ] || [ -z "$ACCESS_TOKEN" ]; then
  erro "Erro ao obter access token!"
fi

# === 2. CAPTURAR LOG DE ERRO E SERIALIZAR COM jq ===
JSON=$(jq -n --arg logs_erro "$(cat error.log)" '{input_data: $logs_erro}')

# === 3. CHAMAR O QUICK COMMAND ===
RESPONSE=$(curl -s -X POST "$QUICK_COMMAND_URL" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$JSON")

echo "$RESPONSE" > lys_response.json

# === 4. Extrair resposta e salvar em Markdown ===
jq -r '.result.answer // .answer // .message // .result' lys_response.json > resposta_lys.md || erro "Falha ao extrair resposta para Markdown."

echo "Resposta salva com sucesso em resposta_lys.md"