#!/bin/bash

# Путь к файлу со списком IP-адресов
IP_LIST="ip_list.txt"

# Порт для проверки
PORT=8545

# Путь к логам и статистике
LOG_FILE="/var/log/port_activity.log"
ACTIVE_IPS_FILE="/var/log/active_ips.txt"
STATS_FILE="/var/log/port_stats.log"

# Текущая дата и время
CURRENT_TIME=$(date "+%Y-%m-%d %H:%M:%S")
CURRENT_HOUR=$(date "+%Y-%m-%d %H:")

# Проверяем, существует ли файл с IP-адресами
if [[ ! -f $IP_LIST ]]; then
    echo "Файл $IP_LIST не найден! Пожалуйста, создайте его и добавьте список IP-адресов."
    exit 1
fi

# Очистка текущего списка активных IP перед проверкой
> "$ACTIVE_IPS_FILE"

# Счетчики для статистики
ACTIVE_COUNT=0
TOTAL_COUNT=0

# Проверка каждого IP-адреса
while IFS= read -r IP; do
    # Пропуск пустых строк и комментариев
    [[ -z "$IP" || "$IP" =~ ^# ]] && continue

    TOTAL_COUNT=$((TOTAL_COUNT + 1))

    # Проверка доступности порта с помощью netcat
    if nc -z -w 3 "$IP" "$PORT"; then
        echo "$CURRENT_TIME - $IP is active" >> "$LOG_FILE"
        echo "$IP" >> "$ACTIVE_IPS_FILE"
        ACTIVE_COUNT=$((ACTIVE_COUNT + 1))
    else
        echo "$CURRENT_TIME - $IP is inactive" >> "$LOG_FILE"
    fi
done < "$IP_LIST"

# Подсчет количества активных IP за последний час
ACTIVE_LAST_HOUR=$(grep "$CURRENT_HOUR" "$LOG_FILE" | grep "is active" | awk '{print $5}' | sort -u | wc -l)

# Запись статистики в файл
echo "$CURRENT_TIME - Active: $ACTIVE_COUNT/$TOTAL_COUNT" >> "$STATS_FILE"
echo "$CURRENT_TIME - Active last hour: $ACTIVE_LAST_HOUR" >> "$STATS_FILE"

# Вывод итогов
echo "Проверка завершена:"
echo "Активных IP: $ACTIVE_COUNT из $TOTAL_COUNT"
echo "Активных за последний час: $ACTIVE_LAST_HOUR"
echo "Текущий список активных IP можно найти в файле: $ACTIVE_IPS_FILE"
echo "Логи находятся в файле: $LOG_FILE"
echo "Статистика работы в файле: $STATS_FILE"
