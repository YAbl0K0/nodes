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

# Отладка: вывести содержимое переменной ACTIVE_IPS
echo "ACTIVE_IPS содержимое:"
echo "$ACTIVE_IPS"

# Проверяем, есть ли активные подключения
if [[ -z "$ACTIVE_IPS" ]]; then
    echo "Нет подключённых IP по порту $PORT."
    exit 0
fi

# Фильтруем пустые строки в IP_LIST
grep -v '^$' "$IP_LIST" > /tmp/filtered_ip_list.txt

# Обновляем лог времени подключения
echo "Подключённые IP и общее время подключения:"
while IFS= read -r IP; do
    # Отладка: вывести текущий IP
    echo "Проверяем IP: $IP"

    # Проверяем корректность IP
    if [[ -z "$IP" ]]; then
        echo "Пропуск пустой строки."
        continue
    fi

    # Проверяем, есть ли IP в списке активных
    if echo "$ACTIVE_IPS" | grep -qw "$IP"; then
        LAST_SEEN=${CONNECTED_IPS["$IP"]}
        if [[ -n "$LAST_SEEN" ]]; then
            CONNECTED_TIME=$((CURRENT_TIME - LAST_SEEN))
            CONNECTED_HOURS=$((CONNECTED_TIME / 3600))
            echo "$IP подключён $CONNECTED_HOURS часов"
        else
            echo "$IP подключён впервые."
        fi
        CONNECTED_IPS["$IP"]=$CURRENT_TIME
    else
        echo "$IP не найден среди активных."
    fi
done < /tmp/filtered_ip_list.txt

# Записываем обновлённые данные в лог-файл
> "$LOG_FILE"
for IP in "${!CONNECTED_IPS[@]}"; do
    echo "$IP ${CONNECTED_IPS["$IP"]}" >> "$LOG_FILE"
done
