#!/usr/bin/env bash
# Worker の /suggest を例で叩いて、返った HTTP の番号と JSON を並べる確認用スクリプト。
# 使い方：SUGGEST_URL=http://localhost:8787 SUGGEST_TOKEN=<.dev.vars の値> scripts/try-suggest.sh
# Workers AI は wrangler dev でも本物を呼ぶ（課金される）ので、回数を増やしすぎない。
set -euo pipefail

: "${SUGGEST_URL:?SUGGEST_URL を指定する（例：http://localhost:8787）}"
: "${SUGGEST_TOKEN:?SUGGEST_TOKEN を指定する（.dev.vars の値）}"

# 名前・本文を受け取り、/suggest に合言葉つきで POST する。
try_suggest() {
  local title="$1" body="$2"
  echo "== ${title}"
  echo "   送る: ${body}"
  curl -sS -w '\n   HTTP %{http_code}\n' -X POST "${SUGGEST_URL}/suggest" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${SUGGEST_TOKEN}" \
    -d "${body}" | sed '1s/^/   返る: /'
}

try_suggest "うどん（弱いラベルだけ）" \
  '{"labels":[{"name":"noodles","confidence":0.22},{"name":"soup","confidence":0.18},{"name":"bowl","confidence":0.12},{"name":"chopsticks","confidence":0.08}]}'
try_suggest "天ぷら" \
  '{"labels":[{"name":"tempura","confidence":0.71},{"name":"food","confidence":0.4},{"name":"fried_food","confidence":0.2}]}'
try_suggest "唐揚げ" \
  '{"labels":[{"name":"fried_chicken","confidence":0.55},{"name":"food","confidence":0.35},{"name":"plate","confidence":0.1}]}'
try_suggest "コーヒー" \
  '{"labels":[{"name":"coffee","confidence":0.8},{"name":"cup","confidence":0.3},{"name":"drink","confidence":0.25}]}'
try_suggest "ケーキ" \
  '{"labels":[{"name":"cake","confidence":0.66},{"name":"dessert","confidence":0.4},{"name":"plate","confidence":0.1}]}'
try_suggest "食べ物でない" \
  '{"labels":[{"name":"desk","confidence":0.6},{"name":"keyboard","confidence":0.45},{"name":"computer","confidence":0.2}]}'
try_suggest "ラーメン（形に合わない名前が混ざる → 捨てて 200）" \
  '{"labels":[{"name":"ramen","confidence":0.62},{"name":"Soup!","confidence":0.12},{"name":"chopsticks","confidence":0.08}]}'
try_suggest "低いラベルだけ（Jev を呼ばずに提案なし）" \
  '{"labels":[{"name":"table","confidence":0.03}]}'
try_suggest "ラベル 0 個（400）" '{"labels":[]}'
try_suggest "confidence が範囲外（400）" '{"labels":[{"name":"ramen","confidence":1.5}]}'
try_suggest "JSON でない（400）" 'not json'

echo "== 合言葉なし（401）"
curl -sS -w '\n   HTTP %{http_code}\n' -X POST "${SUGGEST_URL}/suggest" \
  -H "Content-Type: application/json" -d '{"labels":[{"name":"ramen","confidence":0.6}]}'
echo "== 合言葉が違う（401）"
curl -sS -w '\n   HTTP %{http_code}\n' -X POST "${SUGGEST_URL}/suggest" \
  -H "Content-Type: application/json" -H "Authorization: Bearer wrong" \
  -d '{"labels":[{"name":"ramen","confidence":0.6}]}'
echo "== GET（405）"
curl -sS -w '\n   HTTP %{http_code}\n' "${SUGGEST_URL}/suggest" -H "Authorization: Bearer ${SUGGEST_TOKEN}"
echo "== /search（404）"
curl -sS -w '\n   HTTP %{http_code}\n' -X POST "${SUGGEST_URL}/search" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${SUGGEST_TOKEN}" \
  -d '{"query":"ラーメン"}'
