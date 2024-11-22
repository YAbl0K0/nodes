#!/bin/bash

# Файл со списком IP-адресов
IP_LIST="ip_list.txt"

# Порт для проверки
PORT=8545

# Получение текущей даты в формате YYYY/MM/DD
CURRENT_DATE=$(date '+%Y/%m/%d')

# Проверяем, существует ли файл с IP-адресами
if [[ ! -f $IP_LIST ]]; then
    echo "Файл $IP_LIST не найден! Пожалуйста, создайте его и добавьте список IP-адресов."
    exit 1
fi

# Получаем список IP-адресов, подключенных к порту 8545
CONNECTED_IPS=$(netstat -tn | grep ":$PORT" | awk '{print $5}' | cut -d':' -f1 | sed 's/^::ffff://g' | sort -u)

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
