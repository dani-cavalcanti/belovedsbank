#!/bin/bash

# Este script executa as duas requisições em sequência e imprime a resposta JSON completa.

# Configura o script para sair imediatamente se um comando falhar
set -e

# === Função de erro ===
# Exibe uma mensagem de erro no stderr e encerra o script.
erro() { echo "Erro: $1" >&2; exit 1; }

# === Verificações de requisitos ===
command -v jq >/dev/null 2>&1 || erro "O utilitário 'jq' não está instalado. Instale com: sudo apt-get install jq"
[ -f "error.log" ] || erro "Arquivo 'error.log' não encontrado no diretório atual."

# --- Geração do Access Token ---
TOKEN_URL="https://idm.stackspot.com/${REALM:-stackspot-freemium}/oidc/oauth/token"
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

# Extrai o execution_id e remove as aspas
EXECUTION_ID=$(echo "$RESPONSE" | tr -d '"')
[ -z "$EXECUTION_ID" ] || [ "$EXECUTION_ID" == "null" ] && erro "execution_id não encontrado na resposta do Quick Command!"

echo "Execution ID gerado: $EXECUTION_ID"

# --- Chamada da API de Callback para obter a resposta final ---
echo "Fazendo requisição para a URL de callback..."
RESULT_RESPONSE=$(curl -s -X GET "https://genai-code-buddy-api.stackspot.com/v1/quick-commands/callback/$EXECUTION_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

# --- Impressão da Resposta ---
echo "--- Resposta da Requisição GET ---"
echo "$RESULT_RESPONSE"
