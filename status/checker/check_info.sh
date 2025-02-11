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
    download_speed=$(speedtest --simple | grep "Download" | awk '{print $2 " " $3}')
    upload_speed=$(speedtest --simple | grep "Upload" | awk '{print $2 " " $3}')
    echo -e "Скорость скачивания: ${download_speed}"
    echo -e "Скорость загрузки: ${upload_speed}"
else
    echo "speedtest-cli не установлен. Попробуйте установить его:"
    echo "sudo apt install speedtest-cli -y"
    echo "Или используйте официальный клиент от Ookla:"
    echo "curl -s https://install.speedtest.net/app/cli/install.deb -o speedtest.deb && sudo dpkg -i speedtest.deb && rm speedtest.deb"
    echo "После установки запустите: speedtest"
fi

# Альтернативная проверка скорости интернета
if ! command -v speedtest &> /dev/null || speedtest | grep -q "403 Forbidden"; then
    echo -e "Альтернативный тест скорости загрузки:"
    wget -O /dev/null http://speedtest.tele2.net/10MB.zip 2>&1 | grep -o '[0-9.]* [KMGT]B/s'
fi

# Скорость операций чтения/записи
TEST_FILE=/tmp/testfile
write_speed=$(dd if=/dev/zero of=$TEST_FILE bs=1M count=100 oflag=direct 2>&1 | grep -i "copied" | awk '{print $(NF-1) " " $NF}')
read_speed=$(dd if=$TEST_FILE of=/dev/null bs=1M count=100 2>&1 | grep -i "copied" | awk '{print $(NF-1) " " $NF}')
speed=$(hdparm -t /dev/sda | grep 'Timing buffered disk reads' | awk '{print $11 " " $12}')
rm -f $TEST_FILE
echo -e "Диск (запись): ${write_speed}"
echo -e "Диск (чтение): ${read_speed}"
echo -e "Диск (скорость): ${speed}"

# Завершение работы
echo -e "\n======================================="
