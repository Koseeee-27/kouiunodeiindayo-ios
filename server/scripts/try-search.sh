#!/usr/bin/env bash
# Worker の /search を例で叩いて、返った HTTP の番号と JSON を並べる確認用スクリプト（#85）。
# 使い方：SUGGEST_URL=https://<worker>.workers.dev SUGGEST_TOKEN=<合言葉> scripts/try-search.sh
# Jev は Vercel の本物を呼ぶ（クレジットを使う）ので、回数を増やしすぎない。偽の Jev で確かめるのは npm run check:search。
set -euo pipefail

: "${SUGGEST_URL:?SUGGEST_URL を指定する（例：http://localhost:8787）}"
: "${SUGGEST_TOKEN:?SUGGEST_TOKEN を指定する（.dev.vars の値）}"

# 名前・本文を受け取り、/search に合言葉つきで POST する。
try_search() {
  local title="$1" body="$2"
  echo "== ${title}"
  echo "   送る: ${body}"
  curl -sS -w '\n   HTTP %{http_code}\n' -X POST "${SUGGEST_URL}/search" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${SUGGEST_TOKEN}" \
    -d "${body}" | sed '1s/^/   返る: /'
}

# 端末の中では読めない言い方（アプリが Worker に聞くのはこういう言葉）
try_search "こってりした中華そば" '{"query":"こってりした中華そば"}'
try_search "今年に入ってから飲んだお酒" '{"query":"今年に入ってから飲んだお酒"}'
try_search "甘いもの" '{"query":"甘いもの"}'
try_search "最高だった焼肉" '{"query":"最高だった焼肉"}'
# 端末でも読める言い方（Worker でも同じに読めるか）
try_search "前に食べたうまいラーメン" '{"query":"前に食べたうまいラーメン"}'
try_search "今週の麺" '{"query":"今週の麺"}'
try_search "おいしかったケーキ" '{"query":"おいしかったケーキ"}'
# 読み取れない言葉（200 で全部指定なし）
try_search "こんにちは" '{"query":"こんにちは"}'
try_search "空白だけ（400）" '{"query":"   "}'
