#!/bin/bash

# Файл со списком IP-адресов
IP_LIST="ip_list.txt"

# Файл для отслеживания времени подключения
LOG_FILE="ip_time_log.txt"

# Порт для проверки
PORT=8545

# Получение текущей даты в формате YYYY/MM/DD
CURRENT_DATE=$(date '+%Y/%m/%d')

# Проверяем, существует ли файл с IP-адресами
if [[ ! -f $IP_LIST ]]; then
    echo "Файл $IP_LIST не найден! Пожалуйста, создайте его и добавьте список IP-адресов."
    exit 1
fi

# Проверяем, существует ли файл с логами времени
if [[ ! -f $LOG_FILE ]]; then
    touch "$LOG_FILE"
fi

# Получаем список IP-адресов, подключенных к порту 8545
CONNECTED_IPS=$(netstat -tn | grep ":$PORT" | awk '{print $5}' | cut -d':' -f1 | sed 's/^::ffff://g' | sort -u)

# Обновляем логи времени подключения
for IP in $CONNECTED_IPS; do
    if grep -qw "$IP" "$LOG_FILE"; then
        # Если IP уже есть в логах, увеличиваем общее время подключения
        PREVIOUS_TIME=$(grep "$IP" "$LOG_FILE" | awk '{print $2}')
        NEW_TIME=$((PREVIOUS_TIME + 1))
        sed -i "s/$IP $PREVIOUS_TIME/$IP $NEW_TIME/" "$LOG_FILE"
    else
        # Если IP новый, добавляем его в лог
        echo "$IP 1" >> "$LOG_FILE"
    fi
done

# Проверяем и выводим IP-адреса с их временем подключения
echo "Время подключения IP-адресов:"
cat "$LOG_FILE" | while read -r LINE; do
    IP=$(echo "$LINE" | awk '{print $1}')
    TIME_CONNECTED=$(echo "$LINE" | awk '{print $2}')
    echo "IP: $IP - Время подключения: ${TIME_CONNECTED} сек"
done

# Удаляем из логов IP, которые больше не подключены
while IFS= read -r LINE; do
    LOGGED_IP=$(echo "$LINE" | awk '{print $1}')
    if ! echo "$CONNECTED_IPS" | grep -qw "$LOGGED_IP"; then
        sed -i "/$LOGGED_IP/d" "$LOG_FILE"
    fi
done < "$LOG_FILE"

# Удаляем дублирующиеся IP-адреса из файла
UNIQUE_IPS=$(sort -u "$IP_LIST")

# Проверяем, какие IP-адреса из файла отсутствуют в активных подключениях
echo "Айпи не подключены:"
while IFS= read -r IP; do
    # Пропускаем пустые строки
    if [[ -z $IP ]]; then
        continue
    fi

    # Если IP-адреса нет в активных подключениях, выводим его с датой
    if ! echo "$CONNECTED_IPS" | grep -qw "$IP"; then
        echo "$CURRENT_DATE $IP"
    fi
done <<< "$UNIQUE_IPS"

# Проверяем, какие IP-адреса подключены, но отсутствуют в файле
echo "Этого айпи нет в списке:"
while IFS= read -r IP; do
    # Если IP-адреса нет в файле, выводим его с датой
    if ! echo "$UNIQUE_IPS" | grep -qw "$IP"; then
        echo "$CURRENT_DATE $IP"
    fi
done <<< "$CONNECTED_IPS"

TOTAL_TIME=$(awk '{sum+=$2} END {print sum}' ip_time_log.txt)
echo "Общее время подключения всех IP: $TOTAL_TIME секунд"

