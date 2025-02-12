#!/bin/bash

# Цвета
GREEN='\e[32m'
YELLOW='\e[33m'
RED='\e[31m'
CYAN='\e[36m'
MAGENTA='\e[35m'
BOLD='\e[1m'
RESET='\e[0m'

# Вывод даты и времени
echo -e "\n===== Состояние системы на $(date) =====\n"

# Проверка использования дискового пространства
disk_total=$(df -BG / | awk 'NR==2 {print $2}' | tr -d 'G')
disk_usage=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
color=$GREEN
if (( disk_usage > 85 )); then color=$RED; warning="( Если больше 85 то нужно проверить что занимает место и удалить лишнее. Kоманда для проверки ${BOLD}${CYAN}ncdu /${RESET})";
elif (( disk_usage > 50 )); then color=$YELLOW; warning="";
else warning="";
fi
echo -e "Дисковое пространство(Тотал ${disk_total}): ${color}${disk_usage}%${RESET} занято${warning}"

# Использование оперативной памяти
ram_total=$(free -h | awk '/Mem:/ {print $2}')
ram_used=$(free -h | awk '/Mem:/ {print $3}')
ram_percent=$(free | awk '/Mem:/ {printf "%d", $3/$2 * 100}')
color=$GREEN
if (( ram_percent > 90 )); then color=$RED;
elif (( ram_percent > 50 )); then color=$YELLOW;
fi
echo -e "ОЗУ (Тотал ${ram_total}): ${color}${ram_percent}%${RESET} занято (Норма до 90%)"

# Загрузка процессора
load_avg=$(uptime | awk -F'load average:' '{print $2}' | cut -d, -f1)
color=$GREEN
echo -e "Процессор: ${color}${load_avg}${RESET} средняя загрузка за 1 минуту"

# Проверка скорости интернета (ping)
ping_result=$(ping -c 4 google.com | tail -1 | awk -F'/' '{print $5}')
color=$GREEN
if (( $(echo "$ping_result > 10" | bc -l) )); then color=$RED;
fi
echo -e "Ping: ${color}${ping_result} ms${RESET} (Норма до 10 ms)"

# Проверка скорости интернета
if ! command -v speedtest &> /dev/null; then
    echo -e "${YELLOW}Устанавливаю speedtest-cli...${RESET}"
    sudo apt install speedtest-cli -y || echo -e "${RED}Ошибка установки speedtest-cli!${RESET}"
fi

if command -v speedtest &> /dev/null; then
    download_speed=$(speedtest --simple | grep "Download" | awk '{print $2 " " $3}')
    upload_speed=$(speedtest --simple | grep "Upload" | awk '{print $2 " " $3}')
    echo -e "Скорость отправки: ${GREEN}${download_speed}${RESET} (Норма от 30 Mbit/s)"
    echo -e "Скорость загрузки: ${GREEN}${upload_speed}${RESET} (Норма от 30 Mbit/s)"
else
    echo -e "${RED}Speedtest-cli не удалось установить или запустить. Проверьте соединение и попробуйте вручную.${RESET}"
fi

# Скорость операций чтения/записи
if ! command -v fio &> /dev/null; then
    echo -e "${YELLOW}Устанавливаю fio...${RESET}"
    sudo apt install fio -y || echo -e "${RED}Ошибка установки fio!${RESET}"
fi

if command -v fio &> /dev/null; then
    fio --name=write_test --filename=/tmp/testfile --rw=write --bs=1M --size=100M --numjobs=1 --time_based --runtime=5 --group_reporting
else
    echo -e "${RED}fio не удалось установить или запустить. Проверьте соединение и попробуйте вручную.${RESET}"
fi

# Завершение работы
echo -e "\n======================================="
