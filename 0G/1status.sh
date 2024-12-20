#!/bin/bash

# Порт для проверки
PORT=8545

# Проверяем, установлен ли netstat
if ! command -v netstat &> /dev/null; then
    echo "Команда netstat не найдена. Установите её, чтобы использовать этот скрипт."
    exit 1
fi

# Извлекаем активные соединения по порту
RAW_OUTPUT=$(netstat -tan | grep ":$PORT")

# Проверяем, есть ли активные подключения
if [[ -z "$RAW_OUTPUT" ]]; then
    echo "Нет подключений по порту $PORT."
    exit 0
fi

# Извлекаем только IP-адреса
CONNECTED_IPS=$(echo "$RAW_OUTPUT" | awk '{print $5}' | cut -d':' -f1 | sed 's/^::ffff://g' | sort -u)

# Проверяем, удалось ли извлечь IP-адреса
if [[ -z "$CONNECTED_IPS" ]]; then
    echo "Не удалось извлечь IP-адреса из данных."
    exit 1
fi

# Выводим IP-адреса
echo "Список подключённых IP к порту $PORT:"
echo "$CONNECTED_IPS"
