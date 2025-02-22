#!/bin/bash

# === Переменные ===
LOG_DIR="/root/0g-storage-node/run/log/"
LOG_PATTERN="zgs.log.*"
SYSLOG_FILES=("/var/log/syslog.1" "/var/log/syslog")
DB_PATH="/root/.0gchain/data/tx_index.db/"
DB_SIZE_LIMIT=5368709120  # 5GB в байтах

echo "=== Выполняем очистку логов и базы ==="

# === Очистка логов, если они больше 1GB ===
for file in "${SYSLOG_FILES[@]}"; do
    if [ -f "$file" ]; then
        FILE_SIZE=$(du -b "$file" 2>/dev/null | cut -f1)
        if [ "$FILE_SIZE" -gt 1073741824 ]; then
            truncate -s 0 "$file"
            echo "Очищен: $file"
        fi
    else
        echo "Файл $file не найден, пропускаем."
    fi
done

# === Очистка логов в /root/0g-storage-node/run/log/ ===
FOUND_LOGS=$(find "$LOG_DIR" -type f -name "$LOG_PATTERN" 2>/dev/null)
if [ -n "$FOUND_LOGS" ]; then
    for log_file in $FOUND_LOGS; do
        FILE_SIZE=$(du -b "$log_file" 2>/dev/null | cut -f1)
        if [ "$FILE_SIZE" -gt 1073741824 ]; then
            truncate -s 0 "$log_file"
            echo "Очищен: $log_file"
        fi
    done
else
    echo "Файлы логов по маске $LOG_PATTERN в $LOG_DIR не найдены, пропускаем."
fi

# === Проверяем размер базы перед очисткой ===
if [ -d "$DB_PATH" ]; then
    DB_SIZE=$(du -sb "$DB_PATH" 2>/dev/null | cut -f1)
    if [ -n "$DB_SIZE" ] && [ "$DB_SIZE" -gt "$DB_SIZE_LIMIT" ]; then
        echo "Размер базы $DB_PATH превышает 5GB ($DB_SIZE байт). Начинаем очистку..."
        systemctl stop 0g
        find "$DB_PATH" -type f -mtime +7 -delete
        systemctl start 0g
        echo "Очистка базы и перезапуск 0g завершены"
    else
        echo "Размер базы $DB_PATH в пределах нормы ($DB_SIZE байт). Очистка не требуется."
    fi
else
    echo "Папка базы данных $DB_PATH не найдена. Пропускаем очистку."
fi

# === Добавление в cron ===
CRON_JOB="12 11 * * * find $LOG_DIR -type f -name \"$LOG_PATTERN\" -size +1G -exec truncate -s 0 {} \\;; systemctl stop 0g && find $DB_PATH -type f -mtime +7 -delete && systemctl start 0g"
(crontab -l 2>/dev/null | grep -v "@0gchain/data/tx_index.db"; echo "$CRON_JOB") | crontab -
echo "Задача добавлена в cron (запуск каждый день в 9:00)"

# === Перезапуск cron (на всякий случай) ===
systemctl restart cron
echo "Cron перезапущен"

echo "=== Настройка завершена! Скрипт отработал ==="
