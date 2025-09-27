#!/usr/bin/env bash
set -euo pipefail

# === Настройки ===
RPC="${RPC:-https://evmrpc.0g.ai}"   # можно переопределить: export RPC="https://your-0g-rpc"
FILE="${1:-addresses.txt}"           # входной txt: по одному адресу в строке
OUT="${OUT:-balances.csv}"           # файл результата
ERRLOG="${ERRLOG:-errors.log}"       # файл ошибок
CONCURRENCY="${CONCURRENCY:-10}"      # параллелизм: export CONCURRENCY=16
TIMEOUT="${TIMEOUT:-15}"             # таймаут curl (сек)
RETRIES="${RETRIES:-3}"              # количество ретраев при сетевых ошибках

# === Предпроверки ===
command -v curl >/dev/null || { echo "Нужен curl"; exit 1; }
command -v jq   >/dev/null || { echo "Нужен jq (sudo apt-get install jq -y)"; exit 1; }
command -v python3 >/dev/null || { echo "Нужен python3"; exit 1; }
[[ -f "$FILE" ]] || { echo "Файл с адресами не найден: $FILE"; exit 1; }

# очистим прошлый лог ошибок
: > "$ERRLOG"

# === Хедер CSV ===
echo "Address;Balance_OG" > "$OUT"

query_one() {
  local addr="$1"
  local rpc="$2"
  local timeout="$3"
  local retries="$4"
  local errlog="$5"

  # нормализация строки
  addr="$(echo -n "$addr" | tr -d '[:space:]')"
  [[ -z "$addr" ]] && return 0
  if [[ "$addr" != 0x* ]]; then
    printf "%s\n" "WARN: пропуск (не EVM-адрес): '$addr'" >&2
    printf "%s;%s\n" "$addr" "ERROR"    # фиксируем в CSV как ошибку
    printf "[INVALID] %s\n" "$addr" >>"$errlog"
    return 0
  fi

  local i=0 hex=""
  while :; do
    i=$((i+1))
    # запрос eth_getBalance
    hex=$(curl -sS --max-time "$timeout" "$rpc" \
      -H "content-type: application/json" \
      -d '{"jsonrpc":"2.0","id":1,"method":"eth_getBalance","params":["'"$addr"'","latest"]}' \
      | jq -r '.result // empty') || true

    # успех, если вернулся непустой hex (в том числе "0x0...")
    if [[ -n "$hex" ]]; then
      break
    fi

    # ретраи исчерпаны — ошибка
    if (( i >= retries )); then
      printf "%s\n" "ERROR: не удалось получить баланс для $addr (после $retries попыток)" >&2
      printf "[RPC_ERROR] %s\n" "$addr" >>"$errlog"
      printf "%s;%s\n" "$addr" "ERROR"
      return 0
    fi
    sleep 0.4
  done

  # конвертация hex→wei→OG (18 знаков)
  local wei og
  wei=$(python3 - "$hex" <<'PY'
import sys
x=sys.argv[1]
try:
    v=int(x,16) if x and x!="0x" else 0
except Exception:
    v=0
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

  printf "%s;%s\n" "$addr" "$og"
}

export -f query_one
export RPC TIMEOUT RETRIES ERRLOG

# === Запуск в несколько потоков ===
grep -v '^[[:space:]]*$' "$FILE" | grep -v '^[[:space:]]*#' \
  | xargs -I{} -P "$CONCURRENCY" bash -c 'query_one "$@"' _ '{}' "$RPC" "$TIMEOUT" "$RETRIES" "$ERRLOG" \
  >> "$OUT"

echo "Готово: $OUT"
echo "Лог ошибок (если были): $ERRLOG"
