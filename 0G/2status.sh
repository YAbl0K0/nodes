#!/bin/bash

# Порт для проверки
PORT=8545
# Файл для логирования
LOG_FILE="ip_connection_log.txt"
# Текущее время в секундах
CURRENT_TIME=$(date +%s)

# Создаём лог-файл, если его ещё нет
if [[ ! -f $LOG_FILE ]]; then
    touch "$LOG_FILE"
    echo "Лог-файл $LOG_FILE создан."
fi

# Получаем список текущих подключённых IP
CONNECTED_IPS=$(ss -tan | awk -v port=":$PORT" '$5 ~ port {print $5}' | cut -d':' -f1 | sed 's/^::ffff://g' | sort -u)

# Если нет подключённых IP, фиксируем это в логе
if [[ -z "$CONNECTED_IPS" ]]; then
    echo "Нет подключённых IP по порту $PORT."
    echo "Текущее состояние лог-файла:"
    cat "$LOG_FILE"
    exit 0
fi

# Обновляем данные в логе
echo "Обновление данных для подключённых IP..."
for IP in $CONNECTED_IPS; do
    if grep -q "^$IP " "$LOG_FILE"; then
        # Если IP уже в логе, обновляем данные
        LAST_SEEN=$(grep "^$IP " "$LOG_FILE" | awk '{print $2}')
        TOTAL_TIME=$(grep "^$IP " "$LOG_FILE" | awk '{print $3}')
        NEW_TOTAL_TIME=$((TOTAL_TIME + (CURRENT_TIME - LAST_SEEN)))
        sed -i "s/^$IP .*/$IP $CURRENT_TIME $NEW_TOTAL_TIME/" "$LOG_FILE"
        echo "IP $IP обновлён: общее время подключения $NEW_TOTAL_TIME секунд."
    else
        # Если IP новый, добавляем его в лог
        echo "$IP $CURRENT_TIME 0" >> "$LOG_FILE"
        echo "IP $IP добавлен в лог."
    fi
done

# Обрабатываем отключённые IP
echo "Проверка отключённых IP..."
while IFS= read -r LINE; do
    LOGGED_IP=$(echo "$LINE" | awk '{print $1}')
    LAST_SEEN=$(echo "$LINE" | awk '{print $2}')
    TOTAL_TIME=$(echo "$LINE" | awk '{print $3}')
    if ! echo "$CONNECTED_IPS" | grep -qw "$LOGGED_IP"; then
        echo "IP $LOGGED_IP отключён. Общее время подключения: $((TOTAL_TIME + (CURRENT_TIME - LAST_SEEN))) секунд."
    fi
done < "$LOG_FILE"

# Выводим обновлённый лог
echo "Обновлённый лог подключений:"
cat "$LOG_FILE"
