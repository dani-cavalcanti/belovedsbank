#!/bin/bash

# Este script automatiza o envio de um log de erro para uma API Quick Command,
# aguarda a resposta e salva o resultado em um arquivo Markdown.

# Configura o script para sair imediatamente se um comando falhar
set -e

# === Função de erro ===
# Exibe uma mensagem de erro no stderr e encerra o script.
erro() { echo "Erro: $1" >&2; exit 1; }

# === Verificações de requisitos ===
# Verifica se a ferramenta 'jq' está instalada.
command -v jq >/dev/null 2>&1 || erro "O utilitário 'jq' não está instalado. Instale com: sudo apt-get install jq"

# === Verifica se o arquivo de log existe ===
# Confirma que o arquivo 'error.log' está presente no diretório.
[ -f "error.log" ] || erro "Arquivo 'error.log' não encontrado no diretório atual."

# === Gera o access token ===
# Realiza a chamada para obter o token de acesso.
TOKEN_URL="https://idm.stackspot.com/${REALM:-stackspot-freemium}/oidc/oauth/token"
ACCESS_TOKEN=$(curl -s --connect-timeout 10 --location --request POST "$TOKEN_URL" \
  --header 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode "client_id=${CLIENT_ID}" \
  --data-urlencode 'grant_type=client_credentials' \
  --data-urlencode "client_secret=${CLIENT_SECRET}")

# Verifica se a chamada curl foi bem-sucedida e se o token foi retornado.
[ "$?" -ne 0 ] && erro "Falha na chamada para obter o access token."
ACCESS_TOKEN=$(echo "$ACCESS_TOKEN" | jq -r .access_token)
[ "$ACCESS_TOKEN" == "null" ] || [ -z "$ACCESS_TOKEN" ] && erro "Erro ao obter access token! Verifique as credenciais."

# === Serializa o log de erro para JSON ===
# Lê o conteúdo de 'error.log' e o formata como um payload JSON.
JSON=$(jq -n --arg logs_erro "$(cat error.log)" '{input_data: $logs_erro}')

# === Chama o Quick Command e salva o response ===
# Envia o log para a API e obtém o execution_id.
RESPONSE=$(curl -s --connect-timeout 10 -X POST "https://genai-code-buddy-api.stackspot.com/v1/quick-commands/create-execution/analisar-logs-da-pipeline" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$JSON")

# Verifica se a chamada curl foi bem-sucedida.
[ "$?" -ne 0 ] && erro "Falha na chamada do Quick Command (create-execution)."

# === Extrai o execution_id (trata resposta string ou JSON) ===
# Analisa a resposta para encontrar o ID da execução.
if echo "$RESPONSE" | grep -q '^"'; then
  EXECUTION_ID=$(echo "$RESPONSE" | tr -d '"')
else
  EXECUTION_ID=$(echo "$RESPONSE" | jq -r .execution_id)
fi

[ -z "$EXECUTION_ID" ] || [ "$EXECUTION_ID" == "null" ] && erro "execution_id não encontrado na resposta do Quick Command!"

# === Loop até status COMPLETED ===
# Configura um loop com tempo de espera e limite de tentativas para evitar
# o loop infinito.
MAX_TRIES=180
SLEEP_TIME=5
TRIES=0

echo "Aguardando o resultado do Quick Command. Isso pode levar alguns segundos..."
while [ "$TRIES" -lt "$MAX_TRIES" ]; do
  # Usa -w para obter o tempo de resposta sem poluir a saída principal
  RESULT_RESPONSE=$(curl -s -w "time_total:%{time_total}\n" -X GET "https://genai-code-buddy-api.stackspot.com/v1/quick-commands/callback/$EXECUTION_ID" \
    -H "Authorization: Bearer $ACCESS_TOKEN")

  # Separa o tempo da resposta JSON
  RESPONSE_BODY=$(echo "$RESULT_RESPONSE" | sed 's/time_total:.*//')
  RESPONSE_TIME=$(echo "$RESULT_RESPONSE" | grep "time_total" | cut -d: -f2)

  echo "Tempo de resposta da tentativa $TRIES: $RESPONSE_TIME segundos"

  # Verifica se a resposta é um JSON válido antes de tentar extrair o status.
  STATUS=$(echo "$RESPONSE_BODY" | jq -r '.status')

  if [ "$?" -eq 0 ] && [ "$STATUS" == "COMPLETED" ]; then
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

# === Extrai resposta e gera arquivo Markdown ===
# Extrai a resposta final do JSON e salva no arquivo.
echo "$RESPONSE_BODY" | jq -r '.result.answer' > resposta_lys.md || erro "Falha ao gerar o arquivo Markdown."

echo "Análise concluída. O resultado foi salvo em 'resposta_lys.md'."