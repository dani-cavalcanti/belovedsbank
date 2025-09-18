#!/bin/bash

# === Função de erro ===
erro() {
  echo "Erro: $1"
  exit 1
}

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

if [ "$ACCESS_TOKEN" == "null" ] || [ -z "$ACCESS_TOKEN" ]; then
  erro "Erro ao obter access token!"
fi

# === Serializa o log de erro ===
JSON=$(jq -n --arg logs_erro "$(cat error.log)" '{input_data: $logs_erro}')

# === Chama o Quick Command e salva o response ===
RESPONSE=$(curl -s -X POST "https://genai-code-buddy-api.stackspot.com/v1/quick-commands/create-execution/analisar-logs-da-pipeline" \
-H "Authorization: Bearer $ACCESS_TOKEN" \
-H "Content-Type: application/json" \
-d "$JSON")

echo "Resposta do POST:"
echo "$RESPONSE"

# === Extrai o execution_id ===
EXECUTION_ID=$(echo "$RESPONSE" | jq -r .execution_id)
if [ -z "$EXECUTION_ID" ] || [ "$EXECUTION_ID" == "null" ]; then
  erro "execution_id não encontrado na resposta do Quick Command!"
fi

# === Polling até status COMPLETED ===
for i in {1..10}; do
  RESULT_RESPONSE=$(curl -s -X GET "https://genai-code-buddy-api.stackspot.com/v1/quick-commands/callback/$EXECUTION_ID" \
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

# === Extrai resposta e gera arquivo Markdown ===
jq -r '.result.answer' lys_result.json > resposta_lys.md || erro "Falha ao gerar o arquivo Markdown."
echo "Arquivo Markdown gerado com sucesso: resposta_lys.md"