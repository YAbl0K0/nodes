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

# Функция получения транзакций
get_last_transaction_date() {
    local network=$1
    local api_url=$2
    local api_key=$3
    local wallet=$4

    response=$(curl -s "$api_url?module=account&action=txlist&address=$wallet&startblock=0&endblock=99999999&sort=desc&apikey=$api_key")
    
    if [[ $(echo "$response" | jq '.result | length') -gt 0 ]]; then
        timestamp=$(echo "$response" | jq -r '.result[0].timeStamp')
        date=$(date -d @"$timestamp" "+%Y-%m-%d %H:%M:%S")
        echo "[$network] Адрес: $wallet - Последняя транзакция: $date"
        echo "-----------------------------------------"
    else
        echo "[$network] Адрес: $wallet - Нет транзакций!"
        echo "-----------------------------------------"
    fi
}

# Чтение кошельков из файла и запрос данных
while read -r WALLET_ADDRESS; do
    if [[ -n "$WALLET_ADDRESS" ]]; then
        get_last_transaction_date "BNB (BSC)" "https://api.bscscan.com/api" "$BSC_API_KEY" "$WALLET_ADDRESS"
        get_last_transaction_date "Arbitrum" "https://api.arbiscan.io/api" "$ARB_API_KEY" "$WALLET_ADDRESS"
        get_last_transaction_date "opBNB" "https://api-opbnb.bscscan.com/api" "$OPBNB_API_KEY" "$WALLET_ADDRESS"
        get_last_transaction_date "Mantle" "https://api.mantlescan.xyz/api" "$MNT_API_KEY" "$WALLET_ADDRESS"
    fi
done < "$WALLETS_FILE"


