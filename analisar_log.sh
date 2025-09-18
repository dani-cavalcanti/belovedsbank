#!/bin/bash
# Script para consumir Quick Command StackSpot AI e salvar resposta em Markdown

set -e

# === Função de erro ===
erro() { echo "Erro: $1" >&2; exit 1; }

# === Verificações de requisitos ===
command -v jq >/dev/null 2>&1 || erro "O utilitário 'jq' não está instalado. Instale com: sudo apt-get install jq"
[ -f "error.log" ] || erro "Arquivo 'error.log' não encontrado no diretório atual."

# === Variáveis de ambiente necessárias ===
: "${CLIENT_ID:?Variável CLIENT_ID não definida}"
: "${CLIENT_SECRET:?Variável CLIENT_SECRET não definida}"
REALM="${REALM:-stackspot-freemium}"

# --- Geração do Access Token ---
TOKEN_URL="https://idm.stackspot.com/${REALM}/oidc/oauth/token"
ACCESS_TOKEN=$(curl -s --location --request POST "$TOKEN_URL" \
  --header 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode "client_id=${CLIENT_ID}" \
  --data-urlencode 'grant_type=client_credentials' \
  --data-urlencode "client_secret=${CLIENT_SECRET}" | jq -r .access_token)
[ "$ACCESS_TOKEN" == "null" ] || [ -z "$ACCESS_TOKEN" ] && erro "Erro ao obter access token!"

# --- Chamada da API para criar a execução e obter o ID ---
JSON=$(jq -n --arg logs_erro "$(cat error.log)" '{input_data: $logs_erro}')
RESPONSE=$(curl -s -X POST "https://genai-code-buddy-api.stackspot.com/v1/quick-commands/create-execution/analisar-logs-da-pipeline" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$JSON")
EXECUTION_ID=$(echo "$RESPONSE" | tr -d '"')
[ -z "$EXECUTION_ID" ] || [ "$EXECUTION_ID" == "null" ] && erro "execution_id não encontrado na resposta do Quick Command!"

echo "Execution ID gerado: $EXECUTION_ID"

# --- Polling para aguardar a execução ser concluída ---
echo "Aguardando a execução do Quick Command ser concluída..."
MAX_ATTEMPTS=20
SLEEP_SECONDS=3
ATTEMPT=1
while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
  RESULT_RESPONSE=$(curl -s -X GET "https://genai-code-buddy-api.stackspot.com/v1/quick-commands/callback/$EXECUTION_ID" \
    -H "Authorization: Bearer $ACCESS_TOKEN")
  STATUS=$(echo "$RESULT_RESPONSE" | jq -r '.progress.status')
  echo "Tentativa $ATTEMPT: status = $STATUS"
  if [ "$STATUS" == "COMPLETED" ]; then
    echo "--- Resposta Final ---"
    echo "$RESULT_RESPONSE"
    # Salva o JSON bruto em Markdown
    echo '```json' > resposta_lys.md
    echo "$RESULT_RESPONSE" >> resposta_lys.md
    echo '```' >> resposta_lys.md
    echo "Resposta salva em resposta_lys.md (JSON bruto)"
    # Se quiser salvar só o texto do diagnóstico (ajuste o caminho conforme seu JSON)
    DIAGNOSTICO=$(echo "$RESULT_RESPONSE" | jq -r '.steps[0].step_result.answer')
    if [ "$DIAGNOSTICO" != "null" ] && [ -n "$DIAGNOSTICO" ]; then
      echo -e "\n---\n$DIAGNOSTICO" >> resposta_lys.md
      echo "Diagnóstico extraído também salvo em resposta_lys.md"
    fi
    exit 0
  elif [ "$STATUS" == "FAILED" ]; then
    echo "A execução falhou!"
    echo "$RESULT_RESPONSE"
    exit 1
  fi
  sleep $SLEEP_SECONDS
  ATTEMPT=$((ATTEMPT+1))
done

echo "Timeout: a execução não foi concluída após $((MAX_ATTEMPTS * SLEEP_SECONDS)) segundos."
exit 1