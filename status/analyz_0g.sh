#!/bin/bash

# Файл для отслеживания времени подключения
LOG_FILE="ip_time_log.txt"

# Проверяем, существует ли файл с логами времени
if [[ ! -f $LOG_FILE ]]; then
    echo "Файл $LOG_FILE не найден. Проверьте путь или запустите основной скрипт для создания логов."
    exit 1
fi

# Текущее время (предполагаем, что значения — относительное время в секундах от старта)
CURRENT_TIME=$(date +%s)

# Временные интервалы
TWO_HOURS=$((2 * 3600))

# Списки для вывода
DISCONNECTED_IPS=()
NEW_IPS=()

# Файлы с известными IP
KNOWN_IP_FILE="known_ips.txt"

# Проверяем, существует ли файл с известными IP
if [[ ! -f $KNOWN_IP_FILE ]]; then
    touch "$KNOWN_IP_FILE"
fi

# Обрабатываем каждую строку из лог-файла
while IFS= read -r LINE; do
    IP=$(echo "$LINE" | awk '{print $1}')
    LAST_SEEN=$(echo "$LINE" | awk '{print $2}')

    # Проверяем, чтобы LAST_SEEN был валидным числом
    if [[ ! "$LAST_SEEN" =~ ^[0-9]+$ ]]; then
        echo "Некорректная метка времени для IP: $IP"
        continue
    fi

    # Преобразуем время в читаемый формат (если возможно)
    LAST_SEEN_DATE=$(date -d @"$((CURRENT_TIME - LAST_SEEN))" +"%Y-%m-%d %H:%M:%S" 2>/dev/null)

    # Проверяем, не был ли IP активен последние 2 часа
    if (( LAST_SEEN > TWO_HOURS )); then
        DISCONNECTED_IPS+=("$LAST_SEEN_DATE ; $IP")
    fi

    # Проверяем, является ли IP новым
    if ! grep -qw "$IP" "$KNOWN_IP_FILE"; then
        echo "$IP" >> "$KNOWN_IP_FILE"
        NEW_IPS+=("$LAST_SEEN_DATE ; $IP")
    fi
done < "$LOG_FILE"

# Выводим IP, не активные последние 2 часа
echo "IP, не подключённые последние 2 часа:"
for IP_INFO in "${DISCONNECTED_IPS[@]}"; do
    echo "$IP_INFO"
done

# Выводим новые IP
echo ""
echo "Новые IP:"
for IP_INFO in "${NEW_IPS[@]}"; do
    echo "$IP_INFO"
done
