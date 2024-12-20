#!/bin/bash

# Порт для проверки
PORT=8545

# Проверяем активные подключения к порту
echo "Список подключённых IP к порту $PORT:"
CONNECTED_IPS=$(ss -tan | awk -v port=":$PORT" '$5 ~ port {print $5}' | cut -d':' -f1 | sort -u)

# Проверяем, есть ли активные подключения
if [[ -z "$CONNECTED_IPS" ]]; then
    echo "Нет подключённых IP по порту $PORT."
    exit 0
fi

# Выводим список подключённых IP
echo "$CONNECTED_IPS"
