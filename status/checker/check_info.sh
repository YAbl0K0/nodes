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
warning=""
if (( disk_usage > 85 )); then 
    color=$RED
    warning="${RED}(Забито больше нормы \"85%\" проверьте сервер на лишние файлы и удалите их ${BOLD}${CYAN}команда: ncdu /${RESET}${RED}, если не уверены что можно удалять обратитесь к сапортам)${RESET}"
elif (( disk_usage > 50 )); then 
    color=$YELLOW
fi
echo -e "Дисковое пространство(Тотал ${disk_total}): ${color}${disk_usage}%${RESET} занято (Норма: <= 85%) ${warning}"

# Использование оперативной памяти
ram_total=$(free -h | awk '/Mem:/ {print $2}')
ram_used=$(free -h | awk '/Mem:/ {print $3}')
ram_percent=$(free | awk '/Mem:/ {printf "%d", $3/$2 * 100}')
color=$GREEN
if (( ram_percent > 90 )); then color=$RED;
elif (( ram_percent > 50 )); then color=$YELLOW;
fi
echo -e "ОЗУ (Тотал ${ram_total}): ${color}${ram_percent}%${RESET} занято (Норма: <= 90%)"

# Загрузка процессора
load_avg=$(uptime | awk -F'load average:' '{print $2}' | cut -d, -f1)
cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')
color=$GREEN
if (( $(echo "$cpu_usage > 90" | bc -l) )); then color=$RED;
elif (( $(echo "$cpu_usage > 50" | bc -l) )); then color=$YELLOW;
fi
echo -e "Процессор: Загружено ${color}${cpu_usage}%${RESET}, ${load_avg} средняя загрузка за 1 минуту (Норма: <= 10.0)"

# Проверка скорости интернета (ping)
ping_result=$(ping -c 4 google.com | tail -1 | awk -F'/' '{print $5}')
color=$GREEN
if (( $(echo "$ping_result > 10" | bc -l) )); then color=$RED;
fi
echo -e "Ping: ${color}${ping_result} ms${RESET} (Норма: <= 10 ms)"

# Проверка скорости интернета (Speedtest или wget)
if ! command -v speedtest &> /dev/null; then
    echo -e "${YELLOW}Устанавливаю speedtest-cli...${RESET}"
    sudo apt install speedtest-cli -y > /dev/null 2>&1
fi

if command -v speedtest &> /dev/null; then
    download_speed=$(speedtest --simple | grep "Download" | awk '{print $2 " " $3}')
    upload_speed=$(speedtest --simple | grep "Upload" | awk '{print $2 " " $3}')
else
    echo -e "${RED}Speedtest-cli не удалось использовать, проверяю через wget...${RESET}"
    download_speed=$(wget -O /dev/null http://speedtest.tele2.net/10MB.zip 2>&1 | grep -o '[0-9.]\+ [KM]B/s')
    upload_speed="N/A"
fi
echo -e "Скорость загрузки: ${GREEN}${download_speed}${RESET} (Норма: >= 30 Mbit/s)"
echo -e "Скорость отправки: ${GREEN}${upload_speed}${RESET} (Норма: >= 30 Mbit/s)"

# Проверка и установка sysstat для iostat
if ! command -v iostat &> /dev/null; then
    echo -e "${YELLOW}Устанавливаю sysstat...${RESET}"
    sudo apt install sysstat -y > /dev/null 2>&1
fi

# Скорость операций чтения/записи (fio)
if ! command -v fio &> /dev/null; then
    echo -e "${YELLOW}Устанавливаю fio...${RESET}"
    sudo apt install fio -y > /dev/null 2>&1
fi

if command -v fio &> /dev/null; then
    write_speed=$(fio --name=write_test --filename=/tmp/testfile --rw=write --bs=1M --size=100M --numjobs=1 --time_based --runtime=5 --group_reporting | grep -Eo 'WRITE: bw=[0-9]+MiB/s')
    read_speed=$(fio --name=read_test --filename=/tmp/testfile --rw=read --bs=1M --size=100M --numjobs=1 --time_based --runtime=5 --group_reporting | grep -Eo 'READ: bw=[0-9]+MiB/s')
fi
echo -e "Скорость записи на диск: ${GREEN}${write_speed}${RESET} (Норма: >= 500 MiB/s)"
echo -e "Скорость чтения с диска: ${GREEN}${read_speed}${RESET} (Норма: >= 500 MiB/s)"

# Проверка общей скорости диска
if command -v iostat &> /dev/null; then
    disk_speed=$(iostat -d | awk 'NR==4 {print $2 " MB/s"}')
else
    disk_speed="N/A"
fi
echo -e "Скорость диска: ${GREEN}${disk_speed}${RESET} (Норма: >= 500 MiB/s)"

# Завершение работы
echo -e "\n======================================="
