#!/usr/bin/env bash
set -euo pipefail

# === Настройки ===
RPC="${RPC:-https://evmrpc.0g.ai}"   # можно переопределить: export RPC="https://your-0g-rpc"
FILE="${1:-addresses.txt}"           # входной txt: по одному адресу в строке
OUT="${OUT:-balances.csv}"           # файл результата
CONCURRENCY="${CONCURRENCY:-8}"      # параллелизм: export CONCURRENCY=16
TIMEOUT="${TIMEOUT:-15}"             # таймаут curl (сек)
RETRIES="${RETRIES:-3}"              # количество ретраев при сетевых ошибках

# === Предпроверки ===
command -v curl >/dev/null || { echo "Нужен curl"; exit 1; }
command -v jq   >/dev/null || { echo "Нужен jq (sudo apt-get install jq -y)"; exit 1; }
command -v python3 >/dev/null || { echo "Нужен python3"; exit 1; }
[[ -f "$FILE" ]] || { echo "Файл с адресами не найден: $FILE"; exit 1; }

# === Хедер CSV ===
echo "Address;Balance_OG;Balance_Wei;Hex;Status" > "$OUT"

# === Функция запроса одного адреса ===
query_one() {
  local addr="$1"
  # уберём пробелы/табуляции
  addr="$(echo -n "$addr" | tr -d '[:space:]')"
  [[ -z "$addr" ]] && return 0
  [[ "$addr" != 0x* ]] && { echo "WARN: пропуск строки (непохоже на EVM адрес): '$addr'" >&2; return 0; }

  local i=0 hex status="ok"
  while :; do
    i=$((i+1))
    hex=$(curl -sS --max-time "$TIMEOUT" "$RPC" \
      -H "content-type: application/json" \
      -d '{"jsonrpc":"2.0","id":1,"method":"eth_getBalance","params":["'"$addr"'","latest"]}' \
      | jq -r '.result // empty') || true

    if [[ -n "$hex" && "$hex" != "0x" ]]; then
      break
    fi

    if (( i >= RETRIES )); then
      status="error"
      [[ -z "$hex" ]] && hex="0x"
      break
    fi
    sleep 0.4
  done

  # Переводим в wei и OG (18 знаков)
  # (делаем устойчиво: если пустой/0x — это 0)
  local wei og
  wei=$(python3 - "$hex" <<'PY'
import sys
x=sys.argv[1]
v=int(x,16) if x and x!="0x" else 0
print(v)
PY
)
  og=$(python3 - "$wei" <<'PY'
import sys
from decimal import Decimal, getcontext
getcontext().prec = 80
w=int(sys.argv[1])
print((Decimal(w)/Decimal(10**18)).normalize())
PY
)

  # Пишем строку CSV (адрес;OG;wei;hex;статус)
  echo "$addr;$og;$wei;$hex;$status"
}

export -f query_one
export RPC TIMEOUT RETRIES

# === Запуск в несколько потоков ===
# берём непустые строки и не-комментарии
grep -v '^[[:space:]]*$' "$FILE" | grep -v '^[[:space:]]*#' \
  | xargs -I{} -P "$CONCURRENCY" bash -c 'query_one "$@"' _ '{}' \
  >> "$OUT"

echo "Готово: $OUT"
