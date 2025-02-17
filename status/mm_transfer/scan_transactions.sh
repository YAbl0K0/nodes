#!/bin/bash

# Файл со списком кошельков (один кошелек на строку)
WALLETS_FILE="wallet.txt"

# API-ключи (замени на свои)
BSC_API_KEY="NUCVA3NGW2UKSQX2FTH6VHQMMYA9FVUYAR"
ARB_API_KEY="UIUVBSRNQYYRQTMR4W6IGE3HI7VX7JEUIN"
MNT_API_KEY="KE4UKT9NS27559X79R6628SWVY8IEDFX4M"
OPBNB_API_KEY="2e7962bb77b04722aa9bed6a96d81ad5"

# Проверка наличия файла
if [[ ! -f "$WALLETS_FILE" ]]; then
    echo "Ошибка: Файл $WALLETS_FILE не найден!"
    exit 1
fi

# Функция получения транзакций
get_last_transaction() {
    local network=$1
    local api_url=$2
    local api_key=$3
    local wallet=$4

    response=$(curl -s "$api_url?module=account&action=txlist&address=$wallet&startblock=0&endblock=99999999&sort=desc&apikey=$api_key")
    
    # Проверка наличия транзакций
    if [[ $(echo "$response" | jq '.result | length') -gt 0 ]]; then
        last_tx=$(echo "$response" | jq '.result[0] | {timeStamp, hash, from, to, value, gasPrice}')
        echo "[$network] Адрес: $wallet"
        echo "$last_tx" | jq
        echo "-----------------------------------------"
    else
        echo "[$network] Адрес: $wallet - Нет транзакций!"
        echo "-----------------------------------------"
    fi
}

# Чтение кошельков из файла и запрос данных
while read -r WALLET_ADDRESS; do
    if [[ -n "$WALLET_ADDRESS" ]]; then
        get_last_transaction "BNB (BSC)" "https://api.bscscan.com/api" "$BSC_API_KEY" "$WALLET_ADDRESS"
        get_last_transaction "Arbitrum" "https://api.arbiscan.io/api" "$ARB_API_KEY" "$WALLET_ADDRESS"
        get_last_transaction "opBNB" "https://api.opbnbscan.com/api" "$OPBNB_API_KEY" "$WALLET_ADDRESS"
        get_last_transaction "Mantle" "https://api.mantlescan.io/api" "$MNT_API_KEY" "$WALLET_ADDRESS"
    fi
done < "$WALLETS_FILE"
