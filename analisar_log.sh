#!/bin/bash

# === CONFIGURAÇÕES ===
CLIENT_ID="${CLIENT_ID:-seu_client_id_fixo}"
CLIENT_SECRET="${CLIENT_SECRET:-seu_client_secret_fixo}"
TOKEN_URL="https://idm.stackspot.com/stackspot-freemium/oidc/oauth/token"
QUICK_COMMAND_SLUG="analisar-logs-da-pipeline" # Altere para o slug do seu Quick Command
QUICK_COMMAND_URL="https://genai-code-buddy-api.stackspot.com/v1/quick-commands/create-execution/${QUICK_COMMAND_SLUG}"

# === 1. GERAR ACCESS TOKEN ===
echo "Gerando access token..."
ACCESS_TOKEN=$(curl -s --location --request POST "$TOKEN_URL" \
  --header 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode "client_id=${CLIENT_ID}" \
  --data-urlencode 'grant_type=client_credentials' \
  --data-urlencode "client_secret=${CLIENT_SECRET}" | jq -r .access_token)

if [ "$ACCESS_TOKEN" == "null" ] || [ -z "$ACCESS_TOKEN" ]; then
  echo "Erro ao obter access token!"
  exit 1
fi
echo "Token obtido com sucesso."

# === 2. DEFINA O LOG DE ERRO QUE DESEJA ANALISAR ===
LOG_ERRO=$(cat error.log)

# === 3. CHAMAR O QUICK COMMAND ===
echo "Chamando Quick Command StackSpot AI..."
RESPONSE=$(curl -s -X POST "$QUICK_COMMAND_URL" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"input_data\": \"$LOG_ERRO\"}")

# === 4. SALVAR RESPOSTA EM ARQUIVO ===
echo "$RESPONSE" > lys_response.json
echo "Resposta salva em lys_response.json"

# === 5. (Opcional) Exibir resposta formatada ===
echo "Resumo da resposta:"
jq . lys_response.json