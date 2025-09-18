#!/bin/bash

# === Função de erro ===
erro() {
  echo "Erro: $1"
  exit 1
}

# === Verificações de requisitos ===
command -v jq >/dev/null 2>&1 || erro "O utilitário 'jq' não está instalado. Instale com: sudo apt-get install jq"
command -v pandoc >/dev/null 2>&1 || erro "O utilitário 'pandoc' não está instalado. Instale com: sudo apt-get install pandoc"

# === Verifica se o arquivo de resposta existe ===
[ -f "lys_response.json" ] || erro "Arquivo 'lys_response.json' não encontrado no diretório atual."

# === Extrai o execution_id do arquivo ===
EXECUTION_ID=$(jq -r .execution_id lys_response.json)
if [ -z "$EXECUTION_ID" ] || [ "$EXECUTION_ID" == "null" ]; then
  erro "execution_id não encontrado em lys_response.json!"
fi

# === Gera o access token (ajuste as variáveis conforme necessário) ===
# CLIENT_ID, CLIENT_SECRET e REALM devem estar exportados no ambiente ou definidos aqui
TOKEN_URL="https://idm.stackspot.com/${REALM:-stackspot-freemium}/oidc/oauth/token"
ACCESS_TOKEN=$(curl -s --location --request POST "$TOKEN_URL" \
  --header 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode "client_id=${CLIENT_ID}" \
  --data-urlencode 'grant_type=client_credentials' \
  --data-urlencode "client_secret=${CLIENT_SECRET}" | jq -r .access_token)
if [ "$ACCESS_TOKEN" == "null" ] || [ -z "$ACCESS_TOKEN" ]; then
  erro "Erro ao obter access token!"
fi

# === Faz o GET para buscar o resultado do Quick Command ===
RESPONSE=$(curl -s -X GET "https://genai-code-buddy-api.stackspot.com/v1/quick-commands/callback/$EXECUTION_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

echo "$RESPONSE" > lys_result.json

# === Extrai o campo desejado e converte para Markdown ===
# Ajuste o caminho do jq conforme o campo que deseja extrair!
jq -r '.result.answer' lys_result.json > resposta_lys.md || erro "Falha ao gerar o arquivo Markdown."

echo "Arquivo Markdown gerado com sucesso: resposta_lys.md"