#!/bin/bash

# Файл со списком IP-адресов
IP_LIST="ip_list.txt"

# Порт, который нужно проверить
PORT=8545

# Проверяем, существует ли файл с IP-адресами
if [[ ! -f $IP_LIST ]]; then
    echo "Файл $IP_LIST не найден! Пожалуйста, создайте его и добавьте список IP-адресов."
    exit 1
fi

# Удаляем дубликаты и сохраняем уникальные IP
UNIQUE_IPS=$(sort -u "$IP_LIST")

# Проверяем подключение для каждого уникального IP
while IFS= read -r IP; do
    # Пропускаем пустые строки
    if [[ -z $IP ]]; then
        continue
    fi

    # Проверяем подключение с помощью nc (netcat)
    if ! nc -z -w3 "$IP" "$PORT"; then
        # Если подключение не удалось, выводим IP
        echo "$IP"
    fi
done <<< "$UNIQUE_IPS"
