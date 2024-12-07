#!/bin/bash

# Файл для отслеживания времени подключения
LOG_FILE="ip_time_log.txt"

# Проверяем, существует ли файл с логами времени
if [[ ! -f $LOG_FILE ]]; then
    echo "Файл $LOG_FILE не найден. Проверьте путь или запустите основной скрипт для создания логов."
    exit 1
fi

# Текущее время
CURRENT_TIME=$(date +%s)

# Временной интервал (4 часа в секундах)
TIME_INTERVAL=$((4 * 3600))

echo "Время подключения для каждого IP за последние 4 часа:"

# Обрабатываем каждую строку из лог-файла
while IFS= read -r LINE; do
    IP=$(echo "$LINE" | awk '{print $1}')
    TOTAL_TIME=$(echo "$LINE" | awk '{print $2}')
    LAST_SEEN=$(echo "$LINE" | awk '{print $3}')

    # Рассчитываем время подключения за последние 4 часа
    if (( CURRENT_TIME - LAST_SEEN <= TIME_INTERVAL )); then
        # Учитываем текущее активное подключение
        ACTIVE_TIME=$((CURRENT_TIME - LAST_SEEN))
        TOTAL_FOR_IP=$((TOTAL_TIME + ACTIVE_TIME))
    else
        # Учитываем только зафиксированное общее время
        TOTAL_FOR_IP=$TOTAL_TIME
    fi

    # Выводим IP и время подключения
    echo "$IP: $TOTAL_FOR_IP секунд"
done < "$LOG_FILE"
