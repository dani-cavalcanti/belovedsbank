#!/bin/bash

# === CONFIGURAÇÕES ===
CLIENT_ID="${CLIENT_ID}"
CLIENT_SECRET="${CLIENT_SECRET}"
REALM="${REALM:-stackspot-freemium}"

TOKEN_URL="https://idm.stackspot.com/${REALM}/oidc/oauth/token"
QUICK_COMMAND_SLUG="analisar-logs-da-pipeline"
QUICK_COMMAND_URL="https://genai-code-buddy-api.stackspot.com/v1/quick-commands/create-execution/${QUICK_COMMAND_SLUG}"

# === 1. GERAR ACCESS TOKEN ===
ACCESS_TOKEN=$(curl -s --location --request POST "$TOKEN_URL" \
  --header 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode "client_id=${CLIENT_ID}" \
  --data-urlencode 'grant_type=client_credentials' \
  --data-urlencode "client_secret=${CLIENT_SECRET}" | jq -r .access_token)

if [ "$ACCESS_TOKEN" == "null" ] || [ -z "$ACCESS_TOKEN" ]; then
  echo "Erro ao obter access token!"
  exit 1
fi

# === 2. CAPTURAR LOG DE ERRO E SERIALIZAR COM jq ===
# Isso transforma o conteúdo do log em uma string JSON válida
JSON=$(jq -n --arg logs_erro "$(cat error.log)" '{input_data: $logs_erro}')

# === 3. CHAMAR O QUICK COMMAND ===
RESPONSE=$(curl -s -X POST "$QUICK_COMMAND_URL" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$JSON")

echo "$RESPONSE" > lys_response.json