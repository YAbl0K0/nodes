#!/usr/bin/env bash
set -euo pipefail

# === Настройки ===
RPC="${RPC:-https://evmrpc.0g.ai}"   # export RPC="https://your-0g-rpc"
FILE="${1:-addresses.txt}"           # входной txt: по одному адресу в строке
OUT="${OUT:-balances.csv}"           # файл результата
ERRLOG="${ERRLOG:-errors.log}"       # файл ошибок
CONCURRENCY="${CONCURRENCY:-10}"      # параллелизм: export CONCURRENCY=16
TIMEOUT="${TIMEOUT:-15}"             # таймаут curl (сек)
RETRIES="${RETRIES:-3}"              # количество ретраев
PROGRESS="${PROGRESS:-1}"            # 1=включить прогресс-бар, 0=выключить
PROG_INTERVAL="${PROG_INTERVAL:-0.2}"# частота обновления (сек)

# === Предпроверки ===
command -v curl >/dev/null || { echo "Нужен curl"; exit 1; }
command -v jq   >/dev/null || { echo "Нужен jq (sudo apt-get install jq -y)"; exit 1; }
command -v python3 >/dev/null || { echo "Нужен python3"; exit 1; }
[[ -f "$FILE" ]] || { echo "Файл с адресами не найден: $FILE"; exit 1; }

# Очистим прошлые файлы
: > "$ERRLOG"
echo "Address;Balance_OG" > "$OUT"

# Подсчёт общего количества задач (непустые и не-комментарии)
TOTAL=$(grep -v '^[[:space:]]*$' "$FILE" | grep -v '^[[:space:]]*#' | wc -l | tr -d ' ')
TOTAL=${TOTAL:-0}

# ====== функция запроса одного адреса (как раньше) ======
query_one() {
  local addr="$1"
  local rpc="$2"
  local timeout="$3"
  local retries="$4"
  local errlog="$5"

  addr="$(echo -n "$addr" | tr -d '[:space:]')"
  [[ -z "$addr" ]] && return 0
  if [[ "$addr" != 0x* ]]; then
    printf "%s;%s\n" "$addr" "ERROR" >>"$OUT"
    printf "[INVALID] %s\n" "$addr" >>"$errlog"
    printf "WARN: пропуск (не EVM-адрес): '%s'\n" "$addr" >&2
    return 0
  fi

  local i=0 hex=""
  while :; do
    i=$((i+1))
    hex=$(curl -sS --max-time "$timeout" "$rpc" \
      -H "content-type: application/json" \
      -d '{"jsonrpc":"2.0","id":1,"method":"eth_getBalance","params":["'"$addr"'","latest"]}' \
      | jq -r '.result // empty') || true

    if [[ -n "$hex" ]]; then
      break
    fi
    if (( i >= retries )); then
      printf "%s;%s\n" "$addr" "ERROR" >>"$OUT"
      printf "[RPC_ERROR] %s\n" "$addr" >>"$errlog"
      printf "ERROR: не удалось получить баланс для %s (после %s попыток)\n" "$addr" "$retries" >&2
      return 0
    fi
    sleep 0.4
  done

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

  printf "%s;%s\n" "$addr" "$og" >>"$OUT"
}

export -f query_one
export RPC TIMEOUT RETRIES ERRLOG OUT

# ====== прогресс-бар (фоновый) ======
draw_progress() {
  local total="$1"
  local out="$2"
  local interval="$3"
  local width=40
  # если не TTY — печатаем простой статус в stderr
  local is_tty=0
  if [ -t 1 ]; then is_tty=1; fi

  while :; do
    # готово = строк в OUT минус заголовок
    local done
    done=$(( $(wc -l < "$out") - 1 ))
    (( done < 0 )) && done=0
    (( done > total )) && done=$total

    if (( total > 0 )); then
      local filled=$(( done * width / total ))
      (( filled < 0 )) && filled=0
      (( filled > width )) && filled=$width
      local empty=$(( width - filled ))
      local bar_fill=$(printf "%0.s#" $(seq 1 $filled) 2>/dev/null || true)
      local bar_empty=$(printf "%0.s-" $(seq 1 $empty) 2>/dev/null || true)
      local pct=$(awk -v d="$done" -v t="$total" 'BEGIN{printf "%.1f", (t>0? d*100.0/t : 100)}')
      if (( is_tty )); then
        printf "\r[%s%s] %d/%d (%s%%)" "$bar_fill" "$bar_empty" "$done" "$total" "$pct"
      else
        # не засоряем лог — обновляем не чаще раза в 1.0с
        printf "Progress: %d/%d (%.1f%%)\n" "$done" "$total" "$pct" >&2
      fi
    else
      # если TOTAL=0 (например, файл пуст), ничего не рисуем
      :
    fi

    # завершаем, когда достигли total и основной пайплайн закончен
    if [[ -f "$DONE_FLAG" ]] && (( done >= total )); then
      (( is_tty )) && printf "\n"
      break
    fi
    sleep "$interval"
  done
}

DONE_FLAG="$(mktemp)"
rm -f "$DONE_FLAG" 2>/dev/null || true
trap 'rm -f "$DONE_FLAG" 2>/dev/null || true' EXIT

# Запускаем прогресс-бар в фоне (если включён и есть что обрабатывать)
if (( PROGRESS == 1 )) && (( TOTAL > 0 )); then
  draw_progress "$TOTAL" "$OUT" "$PROG_INTERVAL" &
  PROG_PID=$!
fi

# ====== Основной запуск в несколько потоков ======
# важно: мы больше не пишем в $OUT из нескольких процессов через stdout;
# каждая запись делает сама query_one >> "$OUT" (атомарность строк достаточна)
grep -v '^[[:space:]]*$' "$FILE" | grep -v '^[[:space:]]*#' \
  | xargs -I{} -P "$CONCURRENCY" bash -c 'query_one "$@"' _ '{}' "$RPC" "$TIMEOUT" "$RETRIES" "$ERRLOG"

# сигнализируем прогресс-бару о завершении
: > "$DONE_FLAG"
if [[ -n "${PROG_PID:-}" ]]; then
  wait "$PROG_PID" 2>/dev/null || true
fi

echo "Готово: $OUT"
[[ -s "$ERRLOG" ]] && echo "Есть ошибки, смотри: $ERRLOG" || echo "Ошибок нет"
