#!/usr/bin/env bash
set -euo pipefail

BUNDLE_URL_DEFAULT="https://raw.githubusercontent.com/YAbl0K0/nodes/master/status/mm_transfer/0g_bundle.sh"

RECIPIENT=""
MODE=""                     # <= ПУСТО: скрипт спросит сам (ALL/ONE). Укажи one|all чтобы не спрашивало
VERIFY="strict"             # strict | final
WORKERS="8"
LEAVE_NATIVE="0"
MNEMONICS="mnemonics.txt"
RPC="https://evmrpc.0g.ai"
FROM_IDX="0"
TO_IDX="0"
FORCE_ANY="1"
DRY_RUN="0"
NO_UPDATE_BUNDLE="0"

BUNDLE_URL="$BUNDLE_URL_DEFAULT"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --bundle-url)        BUNDLE_URL="${2:-}"; shift 2;;
    --no-update-bundle)  NO_UPDATE_BUNDLE="1"; shift 1;;
    --recipient)         RECIPIENT="${2:-}"; shift 2;;
    --mode)              MODE="${2:-}"; shift 2;;            # one|all
    --verify|--verify-mode) VERIFY="${2:-}"; shift 2;;
    --workers)           WORKERS="${2:-}"; shift 2;;
    --leave-native)      LEAVE_NATIVE="${2:-}"; shift 2;;
    --mnemonics)         MNEMONICS="${2:-}"; shift 2;;
    --rpc)               RPC="${2:-}"; shift 2;;
    --from-index)        FROM_IDX="${2:-}"; shift 2;;
    --to-index)          TO_IDX="${2:-}"; shift 2;;
    --force-any-words)   FORCE_ANY="1"; shift 1;;
    --bip39-only)        FORCE_ANY="0"; shift 1;;
    --dry-run)           DRY_RUN="1"; shift 1;;
    -h|--help)
cat <<USAGE
Usage: $0 [options]
--bundle-url URL         RAW на 0g_bundle.sh (по умолчанию уже указан)
--no-update-bundle       Не перезакачивать бандл
--recipient 0x...        Адрес X (если не задан — спросит transfer_0g.py)
--mode one|all           Если НЕ указать — будет интерактивный вопрос (ALL/ONE)
--verify strict|final    strict=последовательно; final=параллельно (--workers)
--workers N              Потоков для final (по умолчанию 8)
--leave-native N.NNN     Сколько OG оставить на адресе-источнике (для mode=all)
--mnemonics FILE         Файл сидок
--rpc URL                RPC (default: $RPC)
--from-index N --to-index M   Диапазон индексов
--force-any-words        Разрешить «нестандартные» сиды (PBKDF2) [default ВКЛ]
--bip39-only             Жёсткая проверка BIP-39 (отключить обход)
--dry-run                Только показать адреса (без отправок)
USAGE
      exit 0;;
    *) echo "Неизвестный флаг: $1"; exit 1;;
  esac
done

need() { command -v "$1" >/dev/null 2>&1 || { echo "Нужен $1"; exit 1; }; }
fix_crlf(){ sed -i 's/\r$//' "$1" 2>/dev/null || true; }

BUNDLE_URL="${BUNDLE_URL/\/refs\/heads\/master\//\/master\/}"

need curl
if [[ "$NO_UPDATE_BUNDLE" != "1" ]]; then
  echo "[*] Скачиваю бандл: $BUNDLE_URL"
  curl -fsSL -o 0g_bundle.sh -L "$BUNDLE_URL"
  fix_crlf 0g_bundle.sh; chmod +x 0g_bundle.sh
else
  [[ -f 0g_bundle.sh ]] || { echo "Нет 0g_bundle.sh и включён --no-update-bundle"; exit 1; }
  fix_crlf 0g_bundle.sh; chmod +x 0g_bundle.sh
fi

if [[ ! -d .venv || ! -f transfer_0g.py || ! -f balans_0g.sh ]]; then
  echo "[*] Не найдено окружение/файлы — запускаю бандл (установка)"
  bash 0g_bundle.sh
else
  # shellcheck disable=SC1091
  source .venv/bin/activate
fi
if [[ -d .venv && -z "${VIRTUAL_ENV:-}" ]]; then
  # shellcheck disable=SC1091
  source .venv/bin/activate
fi

[[ -f transfer_0g.py ]] || { echo "transfer_0g.py не найден — проверь бандл"; exit 1; }
[[ -f balans_0g.sh  ]] || { echo "balans_0g.sh не найден — проверь бандл"; exit 1; }
chmod +x balans_0g.sh; fix_crlf balans_0g.sh

cmd=(python3 transfer_0g.py --mnemonics "$MNEMONICS" --rpc "$RPC" --from-index "$FROM_IDX" --to-index "$TO_IDX")
[[ "$DRY_RUN" == "1" ]] && cmd+=(--dry-run)
[[ -n "$RECIPIENT" ]] && cmd+=(--recipient "$RECIPIENT")
[[ -n "$MODE" ]] && cmd+=(--mode "$MODE")          # << добавляем только если задано явно
if [[ "$VERIFY" == "strict" ]]; then cmd+=(--verify-mode strict); else cmd+=(--verify-mode final --workers "$WORKERS"); fi
[[ "$MODE" == "all" ]] && cmd+=(--leave-native "$LEAVE_NATIVE")
[[ "$FORCE_ANY" == "1" ]] && cmd+=(--force-any-words)

echo "[*] Команда запуска:"; printf ' %q' "${cmd[@]}"; echo
exec "${cmd[@]}"
