#!/bin/bash

# Файлы логов
LOG_FILE="ip_time_log.txt"
INACTIVE_LOG_FILE="inactive_ip_log.txt"

# Текущее время (в секундах с начала эпохи UNIX)
CURRENT_TIME=$(date +%s)

echo "Неактивные IP и время неактивности:"
while IFS= read -r LINE; do
    LOGGED_IP=$(echo "$LINE" | awk '{print $1}')
    LOGGED_TIME=$(echo "$LINE" | awk '{print $2}')
    
    # Вычисляем время неактивности (в секундах)
    TIME_DIFF=$((CURRENT_TIME - LOGGED_TIME))

    # Если IP не подключён (не активен сейчас)
    if ! ss -tn | grep ":8545" | awk '{print $5}' | cut -d':' -f1 | grep -qw "$LOGGED_IP"; then
        # Перевод времени неактивности в часы
        TIME_DIFF_HOURS=$((TIME_DIFF / 3600))
        echo "$LOGGED_IP не подключён $TIME_DIFF_HOURS часов"
    fi
done < "$LOG_FILE"
