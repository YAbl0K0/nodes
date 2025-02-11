#!/bin/bash

# Цвета
GREEN='\e[32m'
YELLOW='\e[33m'
RED='\e[31m'
CYAN='\e[36m'
MAGENTA='\e[35m'
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
ram_usage=$(free -h | awk '/Mem:/ {print $3"/"$2}')
echo -e "ОЗУ: ${CYAN}${ram_usage}${RESET}"

# Загрузка процессора
cpu_load=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
color=$GREEN
if (( $(echo "$cpu_load > 80" | bc -l) )); then color=$RED
elif (( $(echo "$cpu_load > 50" | bc -l) )); then color=$YELLOW
fi
echo -e "Процессор: ${color}${cpu_load}%${RESET} загружен"

# Скорость интернета (ping)
ping_result=$(ping -c 4 google.com | tail -1 | awk -F'/' '{print $5}')
echo -e "Ping: ${MAGENTA}${ping_result} ms${RESET}"

# Проверка установки speedtest-cli
if ! command -v speedtest &> /dev/null; then
    echo -e "${YELLOW}Speedtest-cli не установлен. Устанавливаем...${RESET}"
    sudo apt update && sudo apt install -y speedtest-cli
fi

# Проверка скорости интернета
if command -v speedtest &> /dev/null; then
    download_speed=$(speedtest --simple | grep "Download" | awk '{print $2 " " $3}')
    upload_speed=$(speedtest --simple | grep "Upload" | awk '{print $2 " " $3}')
    echo -e "Скорость скачивания: ${CYAN}${download_speed}${RESET}"
    echo -e "Скорость загрузки: ${CYAN}${upload_speed}${RESET}"
else
    echo -e "${RED}Speedtest-cli не удалось установить. Проверьте соединение и попробуйте вручную.${RESET}"
fi

# Скорость операций чтения/записи
TEST_FILE=/tmp/testfile
write_speed=$(dd if=/dev/zero of=$TEST_FILE bs=1M count=100 oflag=direct 2>&1 | grep -i "copied" | awk '{print $(NF-1) " " $NF}')
read_speed=$(dd if=$TEST_FILE of=/dev/null bs=1M count=100 2>&1 | grep -i "copied" | awk '{print $(NF-1) " " $NF}')
speed=$(hdparm -t /dev/sda | grep 'Timing buffered disk reads' | awk '{print $11 " " $12}')
rm -f $TEST_FILE
echo -e "Диск (запись): ${CYAN}${write_speed}${RESET}"
echo -e "Диск (чтение): ${CYAN}${read_speed}${RESET}"
echo -e "Диск (скорость): ${CYAN}${speed}${RESET}"

# Завершение работы
echo -e "\n======================================="
