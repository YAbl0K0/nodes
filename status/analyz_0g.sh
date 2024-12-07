#!/bin/bash

# Файл для отслеживания времени подключения
LOG_FILE="ip_time_log.txt"

# Проверяем, существует ли файл с логами времени
if [[ ! -f $LOG_FILE ]]; then
    echo "Файл $LOG_FILE не найден. Проверьте путь или запустите основной скрипт для создания логов."
    exit 1
fi

# Текущее время
CURRENT_TIME=$(date +%s)

# Временные интервалы
TWO_HOURS=$((2 * 3600))

# Файлы с сохранёнными IP
KNOWN_IP_FILE="known_ips.txt"
NEW_IP_FILE="new_ips.txt"

# Проверяем, существуют ли файлы с известными IP
if [[ ! -f $KNOWN_IP_FILE ]]; then
    touch "$KNOWN_IP_FILE"
fi
if [[ ! -f $NEW_IP_FILE ]]; then
    touch "$NEW_IP_FILE"
fi

# Списки для вывода
DISCONNECTED_IPS=()
NEW_IPS=()

# Обрабатываем каждую строку из лог-файла
while IFS= read -r LINE; do
    IP=$(echo "$LINE" | awk '{print $1}')
    TOTAL_TIME=$(echo "$LINE" | awk '{print $2}')
    LAST_SEEN=$(echo "$LINE" | awk '{print $3}')

    # Проверяем, чтобы LAST_SEEN был валидным числом
    if [[ ! "$LAST_SEEN" =~ ^[0-9]+$ ]]; then
        echo "Некорректная метка времени для IP: $IP"
        continue
    fi

    LAST_SEEN_DATE=$(date -d @"$LAST_SEEN" +"%Y-%m-%d %H:%M:%S" 2>/dev/null)

    # Проверяем, не был ли IP активен последние 2 часа
    if (( CURRENT_TIME - LAST_SEEN > TWO_HOURS )); then
        DISCONNECTED_IPS+=("$LAST_SEEN_DATE ; $IP")
    fi

    # Проверяем, является ли IP новым
    if ! grep -qw "$IP" "$KNOWN_IP_FILE"; then
        echo "$IP" >> "$KNOWN_IP_FILE"
        NEW_IPS+=("$LAST_SEEN_DATE ; $IP")
    fi
done < "$LOG_FILE"

# Сохраняем новые IP в файл
for IP_INFO in "${NEW_IPS[@]}"; do
    echo "$IP_INFO" >> "$NEW_IP_FILE"
done

# Вывод результатов
echo "IP, не подключённые последние 2 часа:"
for IP_INFO in "${DISCONNECTED_IPS[@]}"; do
    echo "$IP_INFO"
done

echo ""
echo "Новые IP:"
for IP_INFO in "${NEW_IPS[@]}"; do
    echo "$IP_INFO"
done
