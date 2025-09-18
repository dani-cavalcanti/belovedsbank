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

# === 4. EXTRAIR EXECUTION_ID E BUSCAR RESULTADO ===
EXECUTION_ID=$(jq -r .execution_id lys_response.json)
if [ -z "$EXECUTION_ID" ] || [ "$EXECUTION_ID" == "null" ]; then
  erro "execution_id não encontrado na resposta do Quick Command!"
fi

# Fazendo polling até o status ser COMPLETED
for i in {1..10}; do
  RESULT_RESPONSE=$(curl -s -X GET "https://genai-code-buddy-api.stackspot.com/v1/quick-commands/callback/${EXECUTION_ID}" \
    -H "Authorization: Bearer $ACCESS_TOKEN")
  STATUS=$(echo "$RESULT_RESPONSE" | jq -r .status)
  if [ "$STATUS" == "COMPLETED" ]; then
    echo "$RESULT_RESPONSE" > lys_result.json
    break
  fi
  echo "Aguardando resultado... (tentativa $i)"
  sleep 3
done

if [ ! -f lys_result.json ]; then
  erro "Resultado não ficou pronto após várias tentativas."
fi

# === 5. Extrair resposta e gerar arquivo Markdown ===
jq -r '.result.answer' lys_result.json > resposta_lys.md || erro "Falha ao gerar o arquivo Markdown."

echo "Arquivo Markdown gerado com sucesso: resposta_lys.md"