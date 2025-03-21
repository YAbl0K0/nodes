#!/bin/bash

# Файл со списком кошельков
WALLETS_FILE="wallet.txt"

# API-ключи
BSC_API_KEY="YZGTSMJB4TW1IB1EK5EFAB8G4UY1T5N31J"
ARB_API_KEY="3M31QUDM1Z8275P4XK1W3PKEGK69MQ2FK6"
MNT_API_KEY="1K3VTVRDK5FESTGDSCDRGDNDIU61BPND55"
OPBNB_API_KEY="UGC3WRVGND8NNNW85R8748FKD4N2RFKQ92"
BASE_API_KEY="3B4KZKM4N5XZP4AD18S8ZU717NY57QZ7BR"

# Проверка наличия файла
if [[ ! -f "$WALLETS_FILE" ]]; then
    echo "Ошибка: Файл $WALLETS_FILE не найден!"
    exit 1
fi

# Функция получения последней транзакции (дата)
get_last_transaction_date() {
    local api_url=$1
    local api_key=$2
    local wallet=$3

    response=$(curl -s "$api_url?module=account&action=txlist&address=$wallet&startblock=0&endblock=99999999&sort=desc&apikey=$api_key")

    # Проверяем статус API и данные
    if [[ -z "$response" || "$(echo "$response" | jq -r '.status')" == "0" || "$(echo "$response" | jq -r '.result')" == "null" ]]; then
        echo "Ошибка API"
        return
    fi

    # Проверяем наличие транзакций
    tx_count=$(echo "$response" | jq '.result | length')
    if [[ "$tx_count" -gt 0 ]]; then
        timestamp=$(echo "$response" | jq -r '.result[0].timeStamp')
        if [[ "$timestamp" =~ ^[0-9]+$ ]]; then
            date=$(date -d @"$timestamp" "+%Y-%m-%d" 2>/dev/null || echo "Ошибка даты")
            echo "$date"
        else
            echo "Ошибка даты"
        fi
    else
        echo "Нет транзакций"
    fi
}

# Функция получения баланса
get_wallet_balance() {
    local api_url=$1
    local api_key=$2
    local wallet=$3

    response=$(curl -s "$api_url?module=account&action=balance&address=$wallet&apikey=$api_key")

    # Проверяем, является ли результат JSON-объектом и статус API
    if [[ -z "$response" || "$(echo "$response" | jq -r '.status')" == "0" ]]; then
        echo "Ошибка API"
        return
    fi

    balance=$(echo "$response" | jq -r '.result')

    # Теперь корректно проверяем баланс, включая ноль
    if [[ "$balance" =~ ^[0-9]+$ ]]; then
        balance=$(printf "%.6f" "$(bc <<< "scale=6; $balance / 1000000000000000000")")
        echo "$balance"
    else
        echo "Ошибка"
    fi
}


# Функция проверки кошелька
check_wallet() {
    local WALLET_ADDRESS=$1

    # Получаем данные последовательно (ждем завершения каждого API-запроса)
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

# Заголовок
echo "Адрес; BSC (Дата); BSC (Баланс); MNT (Дата); MNT (Баланс); opBNB (Дата); opBNB (Баланс); Arbitrum (Дата); Arbitrum (Баланс); Base (Дата); Base (Баланс)"

# Запуск проверки в 20 потоков
MAX_JOBS=2
job_count=0

while read -r WALLET_ADDRESS; do
    if [[ -n "$WALLET_ADDRESS" ]]; then
        check_wallet "$WALLET_ADDRESS" &
        ((job_count++))

        # Если количество активных задач >= MAX_JOBS, ждем их завершения
        if (( job_count >= MAX_JOBS )); then
            wait
            job_count=0
        fi
    fi
done < "$WALLETS_FILE"

wait # Дожидаемся завершения оставшихся процессов
