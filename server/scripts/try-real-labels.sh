#!/usr/bin/env bash
# Mac の Vision で無料素材 6 枚から作った実際のラベル（scripts/real-labels.tsv）を Worker の /suggest に送り、返りを並べる。しきい値を直すときに使う。
# 使い方：SUGGEST_URL=http://localhost:8787 SUGGEST_TOKEN=<合言葉> scripts/try-real-labels.sh
# Jev は wrangler dev でも Vercel の本物を呼ぶ（クレジットを使う）ので、回数を増やしすぎない。
set -euo pipefail

: "${SUGGEST_URL:?SUGGEST_URL を指定する（例：http://localhost:8787）}"
: "${SUGGEST_TOKEN:?SUGGEST_TOKEN を指定する（.dev.vars の値）}"
DIR="$(cd "$(dirname "$0")" && pwd)"

while IFS=$'\t' read -r name body; do
  [[ -z "${name}" || "${name}" == \#* ]] && continue
  printf '== %s\n   送る（上位5つ）: %s\n' "${name}" "$(printf '%s' "${body}" | python3 -c 'import json,sys; d=json.load(sys.stdin)["labels"][:5]; print(", ".join(f"{l["name"]} {l["confidence"]:.2f}" for l in d))')"
  printf '   返る: '
  curl -sS -m 10 -w '  (HTTP %{http_code}, %{time_total}s)\n' -X POST "${SUGGEST_URL}/suggest" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${SUGGEST_TOKEN}" \
    -d "${body}"
  sleep 3
done < "${DIR}/real-labels.tsv"
