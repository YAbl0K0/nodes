#!/bin/bash

# Файлы для логирования
LOG_FILE="ip_time_log.txt"          # Все подключения с временной меткой
INACTIVE_LOG_FILE="inactive_ip_log.txt"  # Отключённые IP

# Порт для мониторинга (можно передать через аргумент командной строки)
PORT=${1:-8545}

# Ассоциативный массив для хранения временных меток активных IP
declare -A ACTIVE_IPS

# Загрузка существующих логов в память
if [[ -f $LOG_FILE ]]; then
    while IFS= read -r line; do
        ip=$(echo "$line" | awk '{print $1}')
        timestamp=$(echo "$line" | awk '{print $2}')
        ACTIVE_IPS["$ip"]=$timestamp
    done < "$LOG_FILE"
fi

# Основной цикл
while true; do
    # Текущее время (в секундах с начала эпохи UNIX)
    CURRENT_TIME=$(date +%s)

    # Получаем список уникальных IP-адресов, подключенных к указанному порту
    CONNECTED_IPS=$(ss -tn "state established" | grep ":$PORT" | awk '{print $5}' | cut -d':' -f1 | sort -u)

    # Обновляем временные метки активных IP
    for IP in $CONNECTED_IPS; do
        ACTIVE_IPS["$IP"]=$CURRENT_TIME
    done

    # Проверяем неактивные IP и обновляем файл логов
    > "$LOG_FILE"  # Очищаем файл перед записью новых данных
    for IP in "${!ACTIVE_IPS[@]}"; do
        LAST_SEEN=${ACTIVE_IPS["$IP"]}
        if (( CURRENT_TIME - LAST_SEEN > 7200 )); then
            # Если IP неактивен более 2 часов, добавляем его в INACTIVE_LOG_FILE
            if ! grep -qw "$IP" "$INACTIVE_LOG_FILE"; then
                echo "$IP $LAST_SEEN" >> "$INACTIVE_LOG_FILE"
            fi
        else
            # Если IP всё ещё активен, записываем его в LOG_FILE
            echo "$IP $LAST_SEEN" >> "$LOG_FILE"
        fi
    done

    # Пауза перед следующей итерацией (в секундах)
    sleep 60
done
