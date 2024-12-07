#!/bin/bash

# Файл для отслеживания времени подключения
LOG_FILE="ip_time_log.txt"

# Проверяем, существует ли файл с логами времени
if [[ ! -f $LOG_FILE ]]; then
    echo "Файл $LOG_FILE не найден. Проверьте путь или запустите основной скрипт для создания логов."
    exit 1
fi

# Текущее время в секундах с момента запуска основного скрипта
CURRENT_TIME=$(awk '{print $2}' "$LOG_FILE" | sort -nr | head -n1)

# Временные интервалы в секундах
TWO_HOURS=$((2 * 3600))

# Списки для вывода
DISCONNECTED_IPS=()
NEW_IPS=()

# Файлы с известными IP
KNOWN_IP_FILE="known_ips.txt"
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

    # Рассчитываем разницу времени
    TIME_DIFF=$((CURRENT_TIME - LAST_SEEN))

    # Преобразуем секунды в часы и минуты
    HOURS=$((TIME_DIFF / 3600))
    MINUTES=$(((TIME_DIFF % 3600) / 60))

    # Форматируем время как HH:MM
    TIME_DIFF_FORMATTED=$(printf "%d:%02d" "$HOURS" "$MINUTES")

    # Преобразуем дату последнего подключения в читаемый формат
    LAST_SEEN_DATE=$(date -d "@$(( $(date +%s) - TIME_DIFF ))" +"%Y-%m-%d")

    # Проверяем, не был ли IP активен последние 2 часа
    if (( TIME_DIFF > TWO_HOURS )); then
        DISCONNECTED_IPS+=("$TIME_DIFF_FORMATTED $LAST_SEEN_DATE $IP")
    fi

    # Проверяем, является ли IP новым
    if ! grep -qw "$IP" "$KNOWN_IP_FILE"; then
        echo "$IP" >> "$KNOWN_IP_FILE"
        NEW_IPS+=("$TIME_DIFF_FORMATTED $LAST_SEEN_DATE $IP")
    fi
done < "$LOG_FILE"

# Выводим результаты
echo "IP, не подключённые последние 2 часа:"
if [[ ${#DISCONNECTED_IPS[@]} -eq 0 ]]; then
    echo "Нет таких IP."
else
    for IP_INFO in "${DISCONNECTED_IPS[@]}"; do
        echo "$IP_INFO"
    done
fi

echo ""
echo "Новые IP:"
if [[ ${#NEW_IPS[@]} -eq 0 ]]; then
    echo "Нет новых IP."
else
    for IP_INFO in "${NEW_IPS[@]}"; do
        echo "$IP_INFO"
    done
fi
