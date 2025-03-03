#!/bin/bash

# Проверка и установка GNU Parallel
if ! command -v parallel &>/dev/null; then
    echo "Установка GNU Parallel..."
    sudo apt update && sudo apt install -y parallel
fi

# Файл со списком кошельков
WALLETS_FILE="wallet.txt"

# API-ключи (экспортируем для parallel)
export BSC_API_KEY="HFMB6Z9IGCGG1CGAHING89K89JJU5FAD2S"
export ARB_API_KEY="UIUVBSRNQYYRQTMR4W6IGE3HI7VX7JEUIN"
export MNT_API_KEY="Y5U5T5IERB24ZBSMCXR35CM8YMJQ8DK91H"
export OPBNB_API_KEY="KMCZ4MTSVURVUPMZNQ9A8CAUMN2PB4BK2C"
export BASE_API_KEY="1VPXAR3DZS7TU957HW9W2S14NXCJ1N6WV8"

# Проверка наличия файла
if [[ ! -f "$WALLETS_FILE" ]]; then
    echo "Ошибка: Файл $WALLETS_FILE не найден!"
    exit 1
fi

# Файл логов
LOG_FILE="api_errors.log"
PARALLEL_LOG="parallel_errors.log"
> "$LOG_FILE"
> "$PARALLEL_LOG"

# Функция проверки кошелька
check_wallet() {
    local WALLET_ADDRESS=$1
    BSC_DATE=$(curl -s "https://api.bscscan.com/api?module=account&action=txlist&address=$WALLET_ADDRESS&startblock=0&endblock=99999999&sort=desc&apikey=$BSC_API_KEY" | jq -r '.result[0].timeStamp // "Нет транзакций"')
    BSC_BALANCE=$(curl -s "https://api.bscscan.com/api?module=account&action=balance&address=$WALLET_ADDRESS&apikey=$BSC_API_KEY" | jq -r '.result // "Ошибка"')

    # Проверка, если баланс - число, то конвертируем
    if [[ "$BSC_BALANCE" =~ ^[0-9]+$ ]]; then
        BSC_BALANCE=$(bc <<< "scale=6; $BSC_BALANCE / 1000000000000000000")
    fi

    printf "%s; %s; %s\n" "$WALLET_ADDRESS" "$BSC_DATE" "$BSC_BALANCE"
}

# Заголовок таблицы
echo "Адрес; BSC (Дата); BSC (Баланс)"

# Экспорт функций и переменных для parallel
export -f check_wallet
export -f get_last_transaction_date get_wallet_balance  # Экспорт всех функций

# Запуск в параллель (5 потоков) с правильным синтаксисом
cat "$WALLETS_FILE" | parallel --env BSC_API_KEY --env ARB_API_KEY --env MNT_API_KEY \
    --env OPBNB_API_KEY --env BASE_API_KEY -j 5 bash -c 'check_wallet "$@"' _ 2>>"$PARALLEL_LOG"
