#!/bin/bash

# Файлы
IP_LIST="ip_list.txt"         # Список IP
LOG_FILE="ip_time_log.txt"    # Лог времени подключения

# Порт для проверки
PORT=8545
# Текущее время
CURRENT_TIME=$(date +%s)

# Проверяем, существует ли файл со списком IP
if [[ ! -f $IP_LIST ]]; then
    echo "Файл $IP_LIST не найден."
    exit 1
fi

# Создаём лог-файл, если он не существует
if [[ ! -f $LOG_FILE ]]; then
    touch "$LOG_FILE"
fi

# Ассоциативный массив для хранения временных меток подключения
declare -A CONNECTED_IPS

# Загружаем предыдущие данные из лога
while IFS= read -r line; do
    IP=$(echo "$line" | awk '{print $1}')
    LAST_SEEN=$(echo "$line" | awk '{print $2}')
    CONNECTED_IPS["$IP"]=$LAST_SEEN
done < "$LOG_FILE"

# Получаем список подключённых IP
ACTIVE_IPS=$(ss -tn | grep ":$PORT" | awk '{print $5}' | cut -d':' -f1 | sort -u)

# Проверяем отключённые IP
echo "Отключённые IP и время неактивности:"
for IP in "${!CONNECTED_IPS[@]}"; do
    if ! echo "$ACTIVE_IPS" | grep -qw "$IP"; then
        LAST_SEEN=${CONNECTED_IPS["$IP"]}
        INACTIVE_TIME=$((CURRENT_TIME - LAST_SEEN))
        INACTIVE_HOURS=$((INACTIVE_TIME / 3600))
        INACTIVE_MINUTES=$(( (INACTIVE_TIME % 3600) / 60 ))
        echo "$IP неактивен $INACTIVE_HOURS часов и $INACTIVE_MINUTES минут"
    fi
done
