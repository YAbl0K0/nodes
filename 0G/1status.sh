#!/bin/bash

# Порт для проверки
PORT=8545

# Извлекаем данные из `ss`
echo "Получение данных от 'ss':"
RAW_OUTPUT=$(ss -tan | grep ":$PORT")
echo "$RAW_OUTPUT"

# Если данных нет, завершаем скрипт
if [[ -z "$RAW_OUTPUT" ]]; then
    echo "Нет подключений по порту $PORT."
    exit 0
fi

# Извлекаем IP-адреса
echo "Извлечение IP-адресов:"
CONNECTED_IPS=$(echo "$RAW_OUTPUT" | awk '{print $5}' | cut -d':' -f1 | sed 's/^::ffff://g' | sort -u)
echo "$CONNECTED_IPS"

# Если IP-адреса пустые, выводим сообщение
if [[ -z "$CONNECTED_IPS" ]]; then
    echo "Не удалось извлечь IP-адреса из данных."
    exit 1
fi

# Выводим список подключённых IP
echo "Список подключённых IP к порту $PORT:"
echo "$CONNECTED_IPS"
