#!/bin/bash

# === Função de erro ===
erro() { echo "Erro: $1"; exit 1; }

# === Verificações de requisitos ===
command -v jq >/dev/null 2>&1 || erro "O utilitário 'jq' não está instalado. Instale com: sudo apt-get install jq"

# === Verifica se o arquivo de log existe ===
[ -f "error.log" ] || erro "Arquivo 'error.log' não encontrado no diretório atual."

# === Gera o access token ===
TOKEN_URL="https://idm.stackspot.com/${REALM:-stackspot-freemium}/oidc/oauth/token"
ACCESS_TOKEN=$(curl -s --location --request POST "$TOKEN_URL" \
  --header 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode "client_id=${CLIENT_ID}" \
  --data-urlencode 'grant_type=client_credentials' \
  --data-urlencode "client_secret=${CLIENT_SECRET}" | jq -r .access_token)

[ "$ACCESS_TOKEN" == "null" ] || [ -z "$ACCESS_TOKEN" ] && erro "Erro ao obter access token!"

# === Serializa o log de erro ===
JSON=$(jq -n --arg logs_erro "$(cat error.log)" '{input_data: $logs_erro}')

# === Chama o Quick Command e salva o response ===
RESPONSE=$(curl -s -X POST "https://genai-code-buddy-api.stackspot.com/v1/quick-commands/create-execution/analisar-logs-da-pipeline" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$JSON")

# === Extrai o execution_id (trata resposta string ou JSON) ===
if echo "$RESPONSE" | grep -q '^"'; then
  EXECUTION_ID=$(echo "$RESPONSE" | tr -d '"')
else
  EXECUTION_ID=$(echo "$RESPONSE" | jq -r .execution_id)
fi

[ -z "$EXECUTION_ID" ] || [ "$EXECUTION_ID" == "null" ] && erro "execution_id não encontrado na resposta do Quick Command!"

# === Loop até status COMPLETED, sem contador, sem sleep, sem mensagens ===
while true; do
  RESULT_RESPONSE=$(curl -s -X GET "https://genai-code-buddy-api.stackspot.com/v1/quick-commands/callback/$EXECUTION_ID" \
    -H "Authorization: Bearer $ACCESS_TOKEN")
  STATUS=$(echo "$RESULT_RESPONSE" | jq -r .status)
  [ "$STATUS" == "COMPLETED" ] && break
done

# === Extrai resposta e gera arquivo Markdown ===
echo "$RESULT_RESPONSE" | jq -r '.result.answer' > resposta_lys.md || erro "Falha ao gerar o arquivo Markdown."