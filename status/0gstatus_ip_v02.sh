#!/bin/bash

# Путь к файлу для записи статистики
LOG_FILE="/var/log/port_check.log"
ACTIVE_IPS_FILE="/var/log/active_ips.txt"

# Путь к файлу со списком IP-адресов
IP_LIST_FILE="ip_list.txt"

# Текущая дата
CURRENT_TIME=$(date "+%Y-%m-%d %H:%M:%S")

# Переменные для статистики
ACTIVE_COUNT=0
TOTAL_COUNT=0

# Очистка файла активных IP
> "$ACTIVE_IPS_FILE"

# Проверка наличия файла с IP
if [[ ! -f "$IP_LIST_FILE" ]]; then
    echo "$CURRENT_TIME - ERROR: IP list file not found at $IP_LIST_FILE" >> "$LOG_FILE"
    exit 1
fi

# Чтение IP-адресов из файла
while IFS= read -r IP; do
    [[ -z "$IP" || "$IP" =~ ^# ]] && continue  # Пропуск пустых строк и комментариев
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    if nc -z -w 3 "$IP" 8545; then
        echo "$CURRENT_TIME - $IP is active" >> "$LOG_FILE"
        echo "$IP" >> "$ACTIVE_IPS_FILE"
        ACTIVE_COUNT=$((ACTIVE_COUNT + 1))
    else
        echo "$CURRENT_TIME - $IP is inactive" >> "$LOG_FILE"
    fi
done < "$IP_LIST_FILE"

# Итоговая статистика
echo "$CURRENT_TIME - Active: $ACTIVE_COUNT/$TOTAL_COUNT" >> "$LOG_FILE"
