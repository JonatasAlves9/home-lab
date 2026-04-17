#!/usr/bin/env bash
# Adds YouTube channels to FreshRSS via GReader API
# Usage: ./setup-youtube-freshrss.sh <freshrss_url> <username> <password>
# Example: ./setup-youtube-freshrss.sh http://manager:8083 admin minhasenha

set -euo pipefail

FRESHRSS_URL="${1:-http://manager:8083}"
USERNAME="${2:-admin}"
PASSWORD="${3:-}"

if [[ -z "$PASSWORD" ]]; then
  echo "Usage: $0 <url> <username> <password>"
  exit 1
fi

API="$FRESHRSS_URL/api/greader.php"

echo "==> Autenticando no FreshRSS..."
AUTH_RESPONSE=$(curl -sf -X POST "$API/accounts/ClientLogin" \
  -d "Email=$USERNAME&Passwd=$PASSWORD")
AUTH_TOKEN=$(echo "$AUTH_RESPONSE" | grep "^Auth=" | cut -d= -f2)

if [[ -z "$AUTH_TOKEN" ]]; then
  echo "ERRO: Falha na autenticação. Verifique usuário/senha e se a API está habilitada."
  echo "  FreshRSS: Configurações > Perfil > Habilitar API"
  exit 1
fi
echo "    OK"

echo "==> Obtendo token de escrita..."
WRITE_TOKEN=$(curl -sf "$API/reader/api/0/token" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN")
echo "    OK"

# YouTube channel RSS URLs
declare -A CHANNELS=(
  ["ThePrimeagen"]="https://www.youtube.com/feeds/videos.xml?channel_id=UCXEuwt31W3ZnXYEbCXQJJXA"
  ["Theo - t3.gg"]="https://www.youtube.com/feeds/videos.xml?channel_id=UCbRP3rBRxpzmkzOmgKHQ_0A"
  ["Codigo Fonte TV"]="https://www.youtube.com/feeds/videos.xml?channel_id=UCFuIUoyHB12qpYa8Jpicld"
  ["Fireship"]="https://www.youtube.com/feeds/videos.xml?channel_id=UCsBjURrPoezykLs9EqgamOA"
  ["Dreams of Code"]="https://www.youtube.com/feeds/videos.xml?channel_id=UCxLMFZA14lsDtKyShTlcwkA"
)

echo ""
echo "==> Adicionando canais do YouTube ao FreshRSS..."
for NAME in "${!CHANNELS[@]}"; do
  URL="${CHANNELS[$NAME]}"
  echo -n "    $NAME ... "
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "$API/reader/api/0/subscription/quickadd" \
    -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" \
    -d "T=$WRITE_TOKEN&quickadd=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$URL'))")")
  if [[ "$HTTP_CODE" == "200" ]]; then
    echo "OK"
  else
    echo "AVISO (HTTP $HTTP_CODE) — pode já existir ou ter falhado"
  fi
done

echo ""
echo "==> Pronto! Acesse FreshRSS em $FRESHRSS_URL para ver os feeds."
echo ""
echo "Para usar no Glance, você precisa do token de API do FreshRSS:"
echo "  FreshRSS > Configurações > Perfil > Token de autenticação da API"
echo ""
echo "URL do feed agregado (substitua TOKEN e USERNAME):"
echo "  $FRESHRSS_URL/i/?a=rss&user=$USERNAME&token=SEU_TOKEN_API"
