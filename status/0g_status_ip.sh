#!/bin/bash

# Файл со списком IP-адресов
IP_LIST="ip_list.txt"

# Порт для проверки
PORT=8545

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
while IFS= read -r IP; do
    # Пропускаем пустые строки
    if [[ -z $IP ]]; then
        continue
    fi

    # Если IP-адреса нет в активных подключениях, выводим его
    if ! echo "$CONNECTED_IPS" | grep -qw "$IP"; then
        echo "$IP"
    fi
done <<< "$UNIQUE_IPS"
