#!/bin/bash

# Проверка и установка GNU Parallel
if ! command -v parallel &>/dev/null; then
    echo "Установка GNU Parallel..."
    sudo apt update && sudo apt install -y parallel
fi

# Файл со списком кошельков
WALLETS_FILE="wallet.txt"

# API-ключи
BSC_API_KEY="HFMB6Z9IGCGG1CGAHING89K89JJU5FAD2S"
ARB_API_KEY="UIUVBSRNQYYRQTMR4W6IGE3HI7VX7JEUIN"
MNT_API_KEY="Y5U5T5IERB24ZBSMCXR35CM8YMJQ8DK91H"
OPBNB_API_KEY="KMCZ4MTSVURVUPMZNQ9A8CAUMN2PB4BK2C"
BASE_API_KEY="1VPXAR3DZS7TU957HW9W2S14NXCJ1N6WV8"

# Проверка наличия файла
if [[ ! -f "$WALLETS_FILE" ]]; then
    echo "Ошибка: Файл $WALLETS_FILE не найден!"
    exit 1
fi

# Файл логов
LOG_FILE="api_errors.log"
> "$LOG_FILE" # Очистить логи перед запуском

# Функция получения последней транзакции
get_last_transaction_date() {
    local api_url=$1
    local api_key=$2
    local wallet=$3

    response=$(curl -s "$api_url?module=account&action=txlist&address=$wallet&startblock=0&endblock=99999999&sort=desc&apikey=$api_key")

    # Проверяем, является ли JSON валидным
    if ! echo "$response" | jq empty 2>/dev/null; then
        echo "[$wallet] Ошибка API (некорректный JSON): $response" >> "$LOG_FILE"
        echo "Ошибка API"
        return
    fi

    # Проверяем, содержит ли JSON поле "result"
    if [[ "$(echo "$response" | jq -r 'has("result")')" == "true" ]]; then
        result=$(echo "$response" | jq '.result')
        
        # Проверка, является ли "result" массивом и содержит ли он элементы
        if [[ "$(echo "$result" | jq 'if type=="array" then length else 0 end')" -gt 0 ]]; then
            timestamp=$(echo "$result" | jq -r '.[0].timeStamp')

            # Проверка, является ли timestamp числом
            if [[ "$timestamp" =~ ^[0-9]+$ ]]; then
                date=$(date -d @"$timestamp" "+%Y-%m-%d" 2>/dev/null)
                if [[ -z "$date" ]]; then
                    echo "[$wallet] Ошибка преобразования даты: $timestamp" >> "$LOG_FILE"
                    echo "Ошибка даты"
                else
                    echo "$date"
                fi
            else
                echo "[$wallet] Ошибка: Некорректный timestamp ($timestamp)" >> "$LOG_FILE"
                echo "Ошибка даты"
            fi
        else
            echo "Нет транзакций"
        fi
    else
        echo "[$wallet] Ошибка API (нет result): $response" >> "$LOG_FILE"
        echo "Ошибка API"
    fi
}

# Функция получения баланса
get_wallet_balance() {
    local api_url=$1
    local api_key=$2
    local wallet=$3
    
    response=$(curl -s "$api_url?module=account&action=balance&address=$wallet&apikey=$api_key")

    # Проверяем, является ли JSON валидным
    if ! echo "$response" | jq empty 2>/dev/null; then
        echo "[$wallet] Ошибка API (некорректный JSON): $response" >> "$LOG_FILE"
        echo "Ошибка API"
        return
    fi

    # Проверяем, содержит ли JSON поле "result"
    if [[ "$(echo "$response" | jq -r 'has("result")')" == "true" ]]; then
        balance=$(echo "$response" | jq -r '.result')

        if [[ "$balance" =~ ^[0-9]+$ ]]; then
            balance=$(printf "%.6f" "$(bc <<< "scale=6; $balance / 1000000000000000000")")
        else
            echo "[$wallet] Ошибка: Некорректный баланс ($balance)" >> "$LOG_FILE"
            balance="Ошибка"
        fi
    else
        echo "[$wallet] Ошибка API (нет result): $response" >> "$LOG_FILE"
        balance="Ошибка API"
    fi
    echo "$balance"
}

# Функция проверки кошелька
check_wallet() {
    local WALLET_ADDRESS=$1
    BSC_DATE=$(get_last_transaction_date "https://api.bscscan.com/api" "$BSC_API_KEY" "$WALLET_ADDRESS")
    BSC_BALANCE=$(get_wallet_balance "https://api.bscscan.com/api" "$BSC_API_KEY" "$WALLET_ADDRESS")

    MNT_DATE=$(get_last_transaction_date "https://api.mantlescan.xyz/api" "$MNT_API_KEY" "$WALLET_ADDRESS")
    MNT_BALANCE=$(get_wallet_balance "https://api.mantlescan.xyz/api" "$MNT_API_KEY" "$WALLET_ADDRESS")

    OPBNB_DATE=$(get_last_transaction_date "https://api-opbnb.bscscan.com/api" "$OPBNB_API_KEY" "$WALLET_ADDRESS")
    OPBNB_BALANCE=$(get_wallet_balance "https://api-opbnb.bscscan.com/api" "$OPBNB_API_KEY" "$WALLET_ADDRESS")

    ARB_DATE=$(get_last_transaction_date "https://api.arbiscan.io/api" "$ARB_API_KEY" "$WALLET_ADDRESS")
    ARB_BALANCE=$(get_wallet_balance "https://api.arbiscan.io/api" "$ARB_API_KEY" "$WALLET_ADDRESS")

    BASE_DATE=$(get_last_transaction_date "https://api.basescan.org/api" "$BASE_API_KEY" "$WALLET_ADDRESS")
    BASE_BALANCE=$(get_wallet_balance "https://api.basescan.org/api" "$BASE_API_KEY" "$WALLET_ADDRESS")

    echo "$WALLET_ADDRESS; $BSC_DATE; $BSC_BALANCE; $MNT_DATE; $MNT_BALANCE; $OPBNB_DATE; $OPBNB_BALANCE; $ARB_DATE; $ARB_BALANCE; $BASE_DATE; $BASE_BALANCE"
}

# Заголовок таблицы
echo "Адрес; BSC (Дата); BSC (Баланс); MNT (Дата); MNT (Баланс); opBNB (Дата); opBNB (Баланс); Arbitrum (Дата); Arbitrum (Баланс); Base (Дата); Base (Баланс)"

# Экспортируем функции и переменные для GNU Parallel
export -f get_last_transaction_date get_wallet_balance check_wallet
export BSC_API_KEY ARB_API_KEY MNT_API_KEY OPBNB_API_KEY BASE_API_KEY

# Запуск в параллель (10 потоков)
cat "$WALLETS_FILE" | parallel -j 10 check_wallet
