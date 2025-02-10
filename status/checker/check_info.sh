#!/bin/bash

# Вывод даты и времени
echo "===== Состояние системы на $(date) ====="

# Проверка использования дискового пространства
echo -e "\nДисковое пространство:"
df -h | awk 'NR==1 || /\/$/'

# Проверка использования оперативной памяти
echo -e "\nИспользование оперативной памяти:"
free -h

# Проверка загрузки процессора
echo -e "\nЗагрузка процессора:"
top -b -n1 | grep "Cpu(s)" | awk '{print "Загрузка: " $2 "% user, " $4 "% system, " $8 "% idle"}'

# Скорость интернет-соединения (ping до Google)
echo -e "\nСкорость интернета (ping):"
ping -c 4 google.com | tail -2

# Тест скорости интернет-соединения (если установлен speedtest-cli)
if command -v speedtest &> /dev/null; then
  echo -e "\nТест скорости интернет-соединения:"
  speedtest --simple
else
  echo -e "\nspeedtest-cli не установлен. Установите его командой: sudo apt install speedtest-cli"
fi

# Скорость операций чтения/записи с диска
echo -e "\nСкорость операций чтения/записи:"
# Используем dd для теста записи
TEST_FILE=/tmp/testfile
dd if=/dev/zero of=$TEST_FILE bs=1M count=100 oflag=direct 2>&1 | grep -i "copied"
rm -f $TEST_FILE

# Окончание работы
echo -e "\n======================================="
