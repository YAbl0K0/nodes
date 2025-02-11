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
cpu_load=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
color=$GREEN
echo -e "Процессор: ${color}${cpu_load}%${RESET} загружен (Норма до 100% не больше 3 дней)"

# Скорость интернета (ping)
ping_result=$(ping -c 4 google.com | tail -1 | awk -F'/' '{print $5}')
color=$GREEN
if (( $(echo "$ping_result > 10" | bc -l) )); then color=$RED;
fi
echo -e "Ping: ${color}${ping_result} ms${RESET} (Норма до 10 ms)"

# Проверка скорости интернета
if command -v speedtest &> /dev/null; then
    download_speed=$(speedtest --simple | grep "Download" | awk '{print $2 " " $3}')
    upload_speed=$(speedtest --simple | grep "Upload" | awk '{print $2 " " $3}')
    echo -e "Скорость отправки: ${GREEN}${download_speed}${RESET} (Норма от 30 Mbit/s)"
    echo -e "Скорость загрузки: ${GREEN}${upload_speed}${RESET} (Норма от 30 Mbit/s)"
else
    echo -e "${RED}Speedtest-cli не удалось установить или запустить. Проверьте соединение и попробуйте вручную.${RESET}"
fi

# Скорость операций чтения/записи
TEST_FILE=/tmp/testfile
write_speed=$(dd if=/dev/zero of=$TEST_FILE bs=1M count=100 oflag=direct 2>&1 | grep -i "copied" | awk '{print $(NF-1) " " $NF}')
read_speed=$(dd if=$TEST_FILE of=/dev/null bs=1M count=100 2>&1 | grep -i "copied" | awk '{print $(NF-1) " " $NF}')
speed=$(hdparm -t /dev/sda | grep 'Timing buffered disk reads' | awk '{print $11 " " $12}')
rm -f $TEST_FILE
echo -e "Диск (запись): ${GREEN}${write_speed}${RESET} (Норма от 500 Mb/s)"
echo -e "Диск (чтение): ${GREEN}${read_speed}${RESET} (Норма от 500 Mb/s)"
echo -e "Диск (скорость): ${GREEN}${speed}${RESET} (Норма от 400 Mb/s)"

# Завершение работы
echo -e "\n======================================="
