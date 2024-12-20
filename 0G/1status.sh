#!/bin/bash

# Порт для проверки
PORT=8545

# Проверяем активные подключения к порту
echo "Список подключённых IP к порту $PORT:"
ss -tn | grep ":$PORT" | awk '{print $5}' | cut -d':' -f1 | sort -u
