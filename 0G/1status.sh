#!/bin/bash

# Порт для проверки
PORT=8545

# Проверяем активные подключения
RAW_OUTPUT=$(ss -tan | grep ":$PORT")

# Если нет данных, выводим сообщение
if [[ -z "$RAW_OUTPUT" ]]; then
    echo "Нет подключений по порту $PORT."
    exit 0
fi

# Извлекаем IP-адреса
CONNECTED_IPS=$(echo "$RAW_OUTPUT" | awk '{print $NF}' | cut -d':' -f1 | sed 's/^::ffff://g' | sort -u)

# Проверяем, удалось ли извлечь IP-адреса
if [[ -z "$CONNECTED_IPS" ]]; then
    echo "Не удалось извлечь IP-адреса."
    exit 1
fi

# Выводим IP-адреса
echo "Список подключённых IP к порту $PORT:"
echo "$CONNECTED_IPS"
