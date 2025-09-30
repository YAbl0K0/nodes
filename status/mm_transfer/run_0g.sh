#!/usr/bin/env bash
set -euo pipefail

# ==== настройки по умолчанию ====
BUNDLE_URL_DEFAULT="https://raw.githubusercontent.com/YAbl0K0/nodes/master/status/mm_transfer/0g_bundle.sh"

RECIPIENT=""                 # если пусто — transfer_0g.py спросит интерактивно
MODE="one"                   # one | all
VERIFY="strict"              # strict | final
WORKERS="8"                  # для verify=final
LEAVE_NATIVE="0"            # сколько OG оставить на U (для mode=all)
MNEMONICS="mnemonics.txt"
RPC="https://evmrpc.0g.ai"
FROM_IDX="0"
TO_IDX="0"
FORCE_ANY="1"               # 1 = --force-any-words (поддержка «нестандартных» сидов)
DRY_RUN="0"                 # 1 = только показать адреса
NO_UPDATE_BUNDLE="0"        # 1 = не скачивать заново

# ==== парсер аргументов ====
BUNDLE_URL="$BUNDLE_URL_DEFAULT"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --bundle-url)        BUNDLE_URL="${2:-}"; shift 2;;
    --no-update-bundle)  NO_UPDATE_BUNDLE="1"; shift 1;;
    --recipient)         RECIPIENT="${2:-}"; shift 2;;
    --mode)              MODE="${2:-}"; shift 2;;
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

--bundle-url URL         RAW-ссылка на 0g_bundle.sh (по умолчанию уже задана)
--no-update-bundle       Не перезаливать бандл (использовать локальный файл)
--recipient 0x...        Адрес X. Если не задан — спросим интерактивно
--mode one|all           one=1 OG, all=всё (минус газ и --leave-native)
--verify strict|final    strict=последовательно; final=параллельно (нужен --workers)
--workers N              Потоков для final (по умолчанию 8)
--leave-native N.NNN     Сколько OG оставить на U (для mode=all)
--mnemonics FILE         Файл сид-фраз
--rpc URL                RPC (default: $RPC)
--from-index N --to-index M   Диапазон индексов (m/44'/60'/0'/0/i)
--force-any-words        Разрешить «нестандартные» сиды (PBKDF2) [по умолчанию ВКЛ]
--bip39-only             Жёсткая проверка BIP-39 (отключить --force-any-words)
--dry-run                Только показать адреса, без отправок
USAGE
      exit 0;;
    *) echo "Неизвестный флаг: $1"; exit 1;;
  esac
done

# ==== утилиты ====
need() { command -v "$1" >/dev/null 2>&1 || { echo "Нужен $1"; exit 1; }; }

fix_crlf() {  # убрать CRLF, если вдруг
  sed -i 's/\r$//' "$1" 2>/dev/null || true
}

# В некоторых ссылках бывает /refs/heads/master/ — нормализуем до /master/
BUNDLE_URL="${BUNDLE_URL/\/refs\/heads\/master\//\/master\/}"

# ==== 1) скачать/обновить бандл ====
need curl
if [[ "$NO_UPDATE_BUNDLE" != "1" ]]; then
  echo "[*] Скачиваю бандл: $BUNDLE_URL"
  curl -fsSL -o 0g_bundle.sh -L "$BUNDLE_URL"
  fix_crlf 0g_bundle.sh
  chmod +x 0g_bundle.sh
else
  [[ -f 0g_bundle.sh ]] || { echo "0g_bundle.sh отсутствует и --no-update-bundle включён"; exit 1; }
  fix_crlf 0g_bundle.sh
  chmod +x 0g_bundle.sh
fi

# ==== 2) venv: создать при отсутствии, иначе активировать ====
if [[ ! -d .venv || ! -f transfer_0g.py || ! -f balans_0g.sh ]]; then
  echo "[*] Не найдено окружение или файлы — запускаю бандл (установка)"
  bash 0g_bundle.sh
else
  echo "[*] Найдено окружение .venv — активирую"
  # shellcheck disable=SC1091
  source .venv/bin/activate
fi

# safety: если бандл только что ставил зависимости, активируем сейчас
if [[ -d .venv && -z "${VIRTUAL_ENV:-}" ]]; then
  # shellcheck disable=SC1091
  source .venv/bin/activate
fi

# убедимся, что файлы на месте
[[ -f transfer_0g.py ]] || { echo "transfer_0g.py не найден — проверь бандл"; exit 1; }
[[ -f balans_0g.sh  ]] || { echo "balans_0g.sh не найден — проверь бандл"; exit 1; }
chmod +x balans_0g.sh
fix_crlf balans_0g.sh

# ==== 3) собрать команду запуска ====
cmd=(python3 transfer_0g.py
      --mnemonics "$MNEMONICS"
      --rpc "$RPC"
      --from-index "$FROM_IDX" --to-index "$TO_IDX")

# режим dry-run
if [[ "$DRY_RUN" == "1" ]]; then
  cmd+=(--dry-run)
fi

# recipient/mode/verify
if [[ -n "$RECIPIENT" ]]; then
  cmd+=(--recipient "$RECIPIENT")
fi
cmd+=(--mode "$MODE")

if [[ "$VERIFY" == "strict" ]]; then
  cmd+=(--verify-mode strict)
else
  cmd+=(--verify-mode final --workers "$WORKERS")
fi

# all-mode: оставить часть нативки
if [[ "$MODE" == "all" ]]; then
  cmd+=(--leave-native "$LEAVE_NATIVE")
fi

# сиды: разрешить «нестандартные»
if [[ "$FORCE_ANY" == "1" ]]; then
  cmd+=(--force-any-words)
fi

echo "[*] Команда запуска:"
printf ' %q' "${cmd[@]}"; echo

# ==== 4) запуск ====
exec "${cmd[@]}"
