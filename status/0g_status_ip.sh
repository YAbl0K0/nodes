#!/bin/bash

# Файл со списком IP-адресов
IP_LIST="ip_list.txt"

# Порт для проверки
PORT=8545

# Логи
DISCONNECTED_LOG="disconnected_ips.log"
UNLISTED_LOG="unlisted_ips.log"

# Получение текущей даты в формате YYYY/MM/DD
CURRENT_DATE=$(date '+%Y/%m/%d %H:%M:%S')

# Проверяем, существует ли файл с IP-адресами
if [[ ! -f $IP_LIST ]]; then
    echo "Файл $IP_LIST не найден! Пожалуйста, создайте его и добавьте список IP-адресов."
    exit 1
fi

# Получаем список IP-адресов, подключенных к порту 8545
CONNECTED_IPS=$(netstat -tn | grep ":$PORT" | awk '{print $5}' | cut -d':' -f1 | sed 's/^::ffff://g' | sort -u)

# Удаляем дублирующиеся IP-адреса из файла
UNIQUE_IPS=$(sort -u "$IP_LIST")

# Логи чистим перед началом
> "$DISCONNECTED_LOG"
> "$UNLISTED_LOG"

# Проверяем, какие IP-адреса из файла отсутствуют в активных подключениях
DISCONNECTED_COUNT=0
echo "Айпи не подключены:" >> "$DISCONNECTED_LOG"
while IFS= read -r IP; do
    # Пропускаем пустые строки
    if [[ -z $IP ]]; then
        continue
    fi

    # Если IP-адреса нет в активных подключениях, выводим его с датой
    if ! echo "$CONNECTED_IPS" | grep -qw "$IP"; then
        echo "$CURRENT_DATE $IP" >> "$DISCONNECTED_LOG"
        DISCONNECTED_COUNT=$((DISCONNECTED_COUNT + 1))
    fi
done <<< "$UNIQUE_IPS"

# Проверяем, какие IP-адреса подключены, но отсутствуют в файле
UNLISTED_COUNT=0
echo "Этого айпи нет в списке:" >> "$UNLISTED_LOG"
while IFS= read -r IP; do
    # Если IP-адреса нет в файле, выводим его с датой
    if ! echo "$UNIQUE_IPS" | grep -qw "$IP"; then
        echo "$CURRENT_DATE $IP" >> "$UNLISTED_LOG"
        UNLISTED_COUNT=$((UNLISTED_COUNT + 1))
    fi
done <<< "$CONNECTED_IPS"

# Общая статистика
echo "==================== СТАТИСТИКА ===================="
echo "Всего IP в списке: $(echo "$UNIQUE_IPS" | wc -l)"
echo "Всего подключенных IP: $(echo "$CONNECTED_IPS" | wc -l)"
echo "Айпи, отсутствующие в подключениях: $DISCONNECTED_COUNT (см. $DISCONNECTED_LOG)"
echo "Айпи, отсутствующие в списке: $UNLISTED_COUNT (см. $UNLISTED_LOG)"
