#!/bin/bash

# Порт для проверки
PORT=8545

# Извлекаем список подключённых IP-адресов
CONNECTED_IPS=$(ss -tan | grep ":$PORT" | awk '{print $5}' | cut -d':' -f1 | sed 's/^::ffff://g' | sort -u)

# Проверяем, есть ли подключённые IP
if [[ -z "$CONNECTED_IPS" ]]; then
    echo "Нет подключённых IP по порту $PORT."
    exit 0
fi

# Выводим список подключённых IP
echo "Список подключённых IP к порту $PORT:"
echo "$CONNECTED_IPS"
