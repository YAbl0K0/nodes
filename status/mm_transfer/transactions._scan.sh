#!/bin/bash

# Файл со списком кошельков (один кошелек на строку)
WALLETS_FILE="wallet.txt"

# API-ключи
BSC_API_KEY="HFMB6Z9IGCGG1CGAHING89K89JJU5FAD2S"
ARB_API_KEY="UIUVBSRNQYYRQTMR4W6IGE3HI7VX7JEUIN"
MNT_API_KEY="Y5U5T5IERB24ZBSMCXR35CM8YMJQ8DK91H"
OPBNB_API_KEY="KMCZ4MTSVURVUPMZNQ9A8CAUMN2PB4BK2C"

# Проверка наличия файла
if [[ ! -f "$WALLETS_FILE" ]]; then
    echo "Ошибка: Файл $WALLETS_FILE не найден!"
    exit 1
fi

# Функция получения последней транзакции (только дата)
get_last_transaction_date() {
    local api_url=$1
    local api_key=$2
    local wallet=$3

    response=$(curl -s "$api_url?module=account&action=txlist&address=$wallet&startblock=0&endblock=99999999&sort=desc&apikey=$api_key")
    
    if [[ $(echo "$response" | jq '.result | length') -gt 0 ]]; then
        timestamp=$(echo "$response" | jq -r '.result[0].timeStamp')
        date=$(date -d @"$timestamp" "+%Y-%m-%d") # Убираем время, оставляем только дату
        echo "$date"
    else
        echo "Нет транзакций"
    fi
}

# Заголовок таблицы
echo "Адрес; BSC; MNT; opBNB; Arbitrum"

# Чтение кошельков из файла и запрос данных
while read -r WALLET_ADDRESS; do
    if [[ -n "$WALLET_ADDRESS" ]]; then
        BSC_DATE=$(get_last_transaction_date "https://api.bscscan.com/api" "$BSC_API_KEY" "$WALLET_ADDRESS")
        MNT_DATE=$(get_last_transaction_date "https://api.mantlescan.xyz/api" "$MNT_API_KEY" "$WALLET_ADDRESS")
        OPBNB_DATE=$(get_last_transaction_date "https://api-opbnb.bscscan.com/api" "$OPBNB_API_KEY" "$WALLET_ADDRESS")
        ARB_DATE=$(get_last_transaction_date "https://api.arbiscan.io/api" "$ARB_API_KEY" "$WALLET_ADDRESS")

        echo "$WALLET_ADDRESS; $BSC_DATE; $MNT_DATE; $OPBNB_DATE; $ARB_DATE"
    fi
done < "$WALLETS_FILE"
