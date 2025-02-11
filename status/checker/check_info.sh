#!/bin/bash

# Цвета
GREEN='\e[32m'
YELLOW='\e[33m'
RED='\e[31m'
RESET='\e[0m'

# Вывод даты и времени
echo -e "\n===== Состояние системы на $(date) =====\n"

# Проверка использования дискового пространства
disk_usage=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
color=$GREEN
if (( disk_usage > 90 )); then color=$RED
elif (( disk_usage > 50 )); then color=$YELLOW
fi
echo -e "Дисковое пространство: ${color}${disk_usage}%${RESET} занято"

# Использование оперативной памяти
echo -e "ОЗУ: $(free -h | awk '/Mem:/ {print $3"/"$2}')"

# Загрузка процессора
cpu_load=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
echo -e "Процессор: ${cpu_load}% загружен"

# Скорость интернета (ping)
ping_result=$(ping -c 4 google.com | tail -1 | awk -F'/' '{print $5}')
echo -e "Ping: ${ping_result} ms"

# Тест скорости интернет-соединения (если установлен speedtest-cli)
if command -v speedtest &> /dev/null; then
    echo -n "Скорость интернета: "
    speedtest --simple | grep "Download" | awk '{print $2 " " $3}'
else
    echo "speedtest-cli не установлен"
fi

# Скорость операций чтения/записи
TEST_FILE=/tmp/testfile
speed_test=$(dd if=/dev/zero of=$TEST_FILE bs=1M count=100 oflag=direct 2>&1 | grep -i "copied" | awk '{print $(NF-1) " " $NF}')
rm -f $TEST_FILE

echo -e "Диск (запись): ${speed_test}"

# Завершение работы
echo -e "\n======================================="
