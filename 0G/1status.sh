#!/bin/bash

# Файл со списком IP
IP_LIST="ip_list.txt"
# Порт для проверки
PORT=8545

# Проверяем, существует ли файл со списком IP
if [[ ! -f $IP_LIST ]]; then
    echo "Файл $IP_LIST не найден. Убедитесь, что он существует."
    exit 1
fi

# Получаем список текущих подключённых IP
CONNECTED_IPS=$(netstat -tan | grep ":$PORT" | awk '{print $5}' | cut -d':' -f1 | sed 's/^::ffff://g' | sort -u)

# Если нет подключённых IP, выводим весь список из `ip_list.txt` как не подключённый
if [[ -z "$CONNECTED_IPS" ]]; then
    echo "Нет подключённых IP по порту $PORT."
    echo "Все IP из $IP_LIST считаются не подключёнными:"
    cat "$IP_LIST"
    exit 0
fi

# Проверяем IP из списка
echo "IP-адреса из $IP_LIST, которые не подключены:"
while IFS= read -r IP; do
    if ! echo "$CONNECTED_IPS" | grep -qw "$IP"; then
        echo "$IP"
    fi
done < "$IP_LIST"
