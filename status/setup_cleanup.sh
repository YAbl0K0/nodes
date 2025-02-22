#!/bin/bash

# === Переменные ===
LOG_DIR="$HOME/0g-storage-node/run/log/"
LOG_PATTERN="zgs.log.2025-*"
SYSLOG_FILES=("/var/log/syslog.1" "/var/log/syslog")
DB_PATH="$HOME/.0gchain/data/tx_index.db/"
DB_SIZE_LIMIT=5368709120  # 5GB в байтах

echo "=== Начинаем очистку логов и базы данных ==="

# === Остановка 0g перед очисткой базы ===
echo "Останавливаем 0g..."
sudo systemctl stop 0g

# === Очистка базы данных ===
if [ -d "$DB_PATH" ]; then
    DB_SIZE=$(du -sb "$DB_PATH" 2>/dev/null | cut -f1)
    if [ -n "$DB_SIZE" ] && [ "$DB_SIZE" -gt "$DB_SIZE_LIMIT" ]; then
        echo "Размер базы $DB_PATH превышает 5GB ($DB_SIZE байт). Начинаем очистку..."
        find "$DB_PATH" -type f -mtime +7 -delete
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

# === Очистка логов в $LOG_DIR ===
if [ -d "$LOG_DIR" ]; then
    echo "Удаляем файлы логов по шаблону $LOG_PATTERN..."
    find "$LOG_DIR" -type f -name "$LOG_PATTERN" -exec rm -f {} +
    echo "Очистка логов завершена."
else
    echo "Директория логов $LOG_DIR не найдена. Пропускаем очистку."
fi

# === Очистка syslog ===
for file in "${SYSLOG_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "Очищаем $file..."
        sudo truncate -s 0 "$file"
    else
        echo "Файл $file не найден, пропускаем."
    fi
done

# === Добавление задачи в cron ===
CRON_JOB="0 9 * * * systemctl stop 0g && find $DB_PATH -type f -mtime +7 -delete && systemctl start 0g && find $LOG_DIR -type f -name 'zgs.log*' -size +1G -exec truncate -s 0 {} +"

# Удаляем старую запись, если она уже существует
(crontab -l 2>/dev/null | grep -v "find $DB_PATH" | grep -v "find $LOG_DIR"; echo "$CRON_JOB") | crontab -
echo "Задача добавлена в cron (ежедневный запуск в 9:00)."

# === Проверяем, работает ли cron, перед перезапуском ===
if systemctl is-active --quiet cron; then
    systemctl restart cron
    echo "Cron перезапущен."
else
    echo "Ошибка: cron не активен! Проверьте его вручную."
fi

echo "=== Очистка завершена! Скрипт отработал ==="
