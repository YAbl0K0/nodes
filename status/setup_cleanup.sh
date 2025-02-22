#!/bin/bash

# === Переменные ===
LOG_DIR="$HOME/0g-storage-node/run/log/"
LOG_PATTERN="zgs.log.2025-*"
SYSLOG_FILES=("/var/log/syslog.1" "/var/log/syslog")
DB_PATH="$HOME/.0gchain/data/tx_index.db/"
DB_SIZE_LIMIT=5368709120  # 5GB в байтах
LOG_SIZE_LIMIT=1073741824  # 1GB в байтах

echo "=== Начинаем очистку логов и базы данных ==="

# === Остановка 0g перед очисткой базы ===
echo "Останавливаем 0g..."
sudo systemctl stop 0g
sleep 5

if systemctl is-active --quiet 0g; then
    echo "Ошибка: процесс 0g не остановился, принудительное завершение..."
    sudo systemctl kill 0g
fi

# === Очистка базы данных, если размер превышает 5 ГБ ===
if [ -d "$DB_PATH" ]; then
    DB_SIZE=$(du -sb "$DB_PATH" 2>/dev/null | cut -f1)
    if [ -n "$DB_SIZE" ] && [ "$DB_SIZE" -gt "$DB_SIZE_LIMIT" ]; then
        echo "Размер базы $DB_PATH превышает 5GB ($DB_SIZE байт). Начинаем очистку..."
        find "$DB_PATH" -type f -name "*.tmp" -mtime +7 -delete
        echo "Очистка базы данных завершена."
    else
        echo "Размер базы $DB_PATH в пределах нормы ($DB_SIZE байт). Очистка не требуется."
    fi
else
    echo "Папка базы данных $DB_PATH не найдена. Пропускаем очистку."
fi

# === Запуск 0g после очистки базы ===
echo "Запускаем 0g..."
sudo systemctl start 0g

# === Очистка логов в $LOG_DIR, если они больше 1 ГБ ===
if [ -d "$LOG_DIR" ]; then
    echo "Проверяем файлы логов по шаблону $LOG_PATTERN..."
    find "$LOG_DIR" -type f -name "$LOG_PATTERN" | while read -r log_file; do
        LOG_SIZE=$(du -b "$log_file" | cut -f1)
        if [ "$LOG_SIZE" -gt "$LOG_SIZE_LIMIT" ]; then
            echo "Очищаем $log_file (размер: $LOG_SIZE байт)..."
            truncate -s 0 "$log_file"
        fi
    done
    echo "Очистка логов завершена."
else
    echo "Директория логов $LOG_DIR не найдена. Пропускаем очистку."
fi

# === Очистка syslog, если он больше 1 ГБ ===
for file in "${SYSLOG_FILES[@]}"; do
    if [ -f "$file" ]; then
        FILE_SIZE=$(du -b "$file" | cut -f1)
        if [ "$FILE_SIZE" -gt "$LOG_SIZE_LIMIT" ]; then
            echo "Очищаем $file (размер: $FILE_SIZE байт)..."
            sudo truncate -s 0 "$file"
        else
            echo "Размер $file в пределах нормы ($FILE_SIZE байт). Очистка не требуется."
        fi
    else
        echo "Файл $file не найден, пропускаем."
    fi
done

# === Добавление задачи в cron ===
CRON_JOB="0 9 * * * systemctl stop 0g && find $DB_PATH -type f -name \"*.tmp\" -mtime +7 -delete && systemctl start 0g && find $LOG_DIR -type f -name 'zgs.log*' -size +1G -exec truncate -s 0 {} +"

# Проверяем, есть ли уже эта задача в crontab
if ! crontab -l 2>/dev/null | grep -q "find $DB_PATH"; then
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo "Задача добавлена в cron (ежедневный запуск в 9:00)."
else
    echo "Задача уже существует в crontab. Повторное добавление не требуется."
fi

# === Проверяем, работает ли cron, перед перезапуском ===
if systemctl is-active --quiet cron; then
    systemctl restart cron
    echo "Cron перезапущен."
else
    echo "Ошибка: cron не активен! Попытка запуска..."
    sudo systemctl start cron
fi

echo "=== Очистка завершена! Скрипт отработал ==="
