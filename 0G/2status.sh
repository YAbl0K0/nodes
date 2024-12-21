#!/bin/bash

# Порт для проверки
PORT=8545
# Файл для логирования
LOG_FILE="ip_connection_log.txt"
# Текущее время в секундах
CURRENT_TIME=$(date +%s)

# Проверяем, установлен ли netstat
if ! command -v netstat &> /dev/null; then
    echo "Команда netstat не найдена. Установите её, чтобы использовать этот скрипт."
    exit 1
fi

# Создаём лог-файл, если его ещё нет
if [[ ! -f $LOG_FILE ]]; then
    touch "$LOG_FILE"
    echo "Лог-файл $LOG_FILE создан."
fi

# Получаем список подключённых IPv4-адресов с помощью netstat
RAW_OUTPUT=$(netstat -tan | grep ":$PORT" | grep -E "tcp.*ESTABLISHED")

# Если вывод пустой, значит подключений нет
if [[ -z "$RAW_OUTPUT" ]]; then
    echo "Нет подключённых IP по порту $PORT."
    echo "Текущее состояние лог-файла:"
    cat "$LOG_FILE"
    exit 0
fi

# Извлекаем только IPv4-адреса
CONNECTED_IPS=$(echo "$RAW_OUTPUT" | awk '{print $5}' | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u)

# Проверяем, удалось ли извлечь IP
if [[ -z "$CONNECTED_IPS" ]]; then
    echo "Не удалось извлечь IPv4-адреса из данных."
    exit 1
fi

# Печатаем извлечённые IP
echo "Извлечённые IPv4-адреса:"
echo "$CONNECTED_IPS"

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

# Выводим обновлённый лог
echo "Обновлённый лог подключений:"
cat "$LOG_FILE"
