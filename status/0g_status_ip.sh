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

# Проходим по каждому IP-адресу в файле
while IFS= read -r IP; do
    # Пропускаем пустые строки
    if [[ -z $IP ]]; then
        continue
    fi

    echo "Проверка подключения к $IP:$PORT..."
    
    # Проверяем подключение с помощью nc (netcat)
    if nc -z -w3 "$IP" "$PORT"; then
        echo "Успешно подключено к $IP:$PORT"
    else
        echo "Не удалось подключиться к $IP:$PORT"
    fi
done < "$IP_LIST"
