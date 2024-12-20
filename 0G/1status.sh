#!/bin/bash

# Порт для проверки
PORT=8545

# Извлекаем IP-адреса из подключений
CONNECTED_IPS=$(ss -tan | awk -v port=":$PORT" '$5 ~ port {print $5}' | cut -d':' -f1 | sed 's/^::ffff://g' | sort -u)

# Проверяем, есть ли подключённые IP
if [[ -z "$CONNECTED_IPS" ]]; then
    echo "Нет подключённых IP по порту $PORT."
    exit 0
fi

# Выводим только IP-адреса
echo "$CONNECTED_IPS"
