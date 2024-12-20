#!/bin/bash

# Файл для логирования
LOG_FILE="ip_connection_log.txt"
# Интервал для проверки в секундах (2 часа)
CHECK_INTERVAL=$((2 * 3600))
# Текущее время
CURRENT_TIME=$(date +%s)

# Проверяем, существует ли лог-файл
if [[ ! -f $LOG_FILE ]]; then
    echo "Лог-файл $LOG_FILE не найден. Запустите скрипт для логирования подключений."
    exit 1
fi

# Проверяем лог и выводим IP, которые не были подключены последние 2 часа
echo "IP-адреса, которые не были подключены последние 2 часа:"
while IFS= read -r LINE; do
    IP=$(echo "$LINE" | awk '{print $1}')
    LAST_SEEN=$(echo "$LINE" | awk '{print $2}')
    if (( CURRENT_TIME - LAST_SEEN > CHECK_INTERVAL )); then
        echo "$IP"
    fi
done < "$LOG_FILE"
