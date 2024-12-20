#!/bin/bash

# Порт для проверки
PORT=8545

# Извлекаем активные подключения по порту
RAW_OUTPUT=$(ss -tan | grep ":$PORT")

# Проверяем, есть ли активные подключения
if [[ -z "$RAW_OUTPUT" ]]; then
    echo "Нет подключений по порту $PORT."
    exit 0
fi

# Обрабатываем данные, извлекая только IP-адреса клиентов
CONNECTED_IPS=$(echo "$RAW_OUTPUT" | awk '{print $5}' | cut -d':' -f1 | sed 's/^::ffff://g' | sort -u)

# Проверяем, удалось ли извлечь IP-адреса
if [[ -z "$CONNECTED_IPS" ]]; then
    echo "Не удалось извлечь IP-адреса из данных."
    exit 1
fi

# Выводим IP-адреса клиентов
echo "Список подключённых IP к порту $PORT:"
echo "$CONNECTED_IPS"
