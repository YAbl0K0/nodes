#!/bin/bash

# Порт для проверки
PORT=8545

# Извлекаем сырой вывод `ss`
RAW_OUTPUT=$(ss -tan | grep ":$PORT")

# Проверяем, есть ли данные в выводе
if [[ -z "$RAW_OUTPUT" ]]; then
    echo "Нет подключённых IP по порту $PORT."
    exit 0
fi

# Извлекаем только IP-адреса
CONNECTED_IPS=$(echo "$RAW_OUTPUT" | awk '{print $6}' | cut -d':' -f1 | sed 's/^::ffff://g' | sort -u)

# Проверяем, есть ли извлечённые IP
if [[ -z "$CONNECTED_IPS" ]]; then
    echo "Не удалось извлечь IP-адреса из данных."
    exit 1
fi

# Выводим список подключённых IP
echo "Список подключённых IP к порту $PORT:"
echo "$CONNECTED_IPS"
