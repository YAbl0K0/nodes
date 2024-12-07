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

# Итоговый подсчёт времени подключения
TOTAL_CONNECTED_TIME=0

# Обрабатываем каждую строку из лог-файла
while IFS= read -r LINE; do
    IP=$(echo "$LINE" | awk '{print $1}')
    TOTAL_TIME=$(echo "$LINE" | awk '{print $2}')
    LAST_SEEN=$(echo "$LINE" | awk '{print $3}')

    # Если IP был активен за последние 4 часа
    if (( CURRENT_TIME - LAST_SEEN <= TIME_INTERVAL )); then
        # Учитываем текущее подключение
        ACTIVE_TIME=$((CURRENT_TIME - LAST_SEEN))
        TOTAL_CONNECTED_TIME=$((TOTAL_CONNECTED_TIME + TOTAL_TIME + ACTIVE_TIME))
    else
        # Учитываем только зафиксированное время
        if (( TOTAL_TIME > 0 )); then
            TOTAL_CONNECTED_TIME=$((TOTAL_CONNECTED_TIME + TOTAL_TIME))
        fi
    fi
done < "$LOG_FILE"

# Выводим итоговое время
echo "Общее время подключения серверов за последние 4 часа: $TOTAL_CONNECTED_TIME секунд"
