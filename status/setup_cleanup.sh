#!/bin/bash

# === Переменные ===
LOG_FILES=("/var/log/syslog.1" "/var/log/syslog" "/root/0g-storage-node/run/log/zgs.log.*")
DB_PATH="/root/.0gchain/data/tx_index.db/"
DB_SIZE_LIMIT=5368709120  # 5GB в байтах

echo "=== Выполняем очистку логов и базы ==="

# === Очистка логов, если они больше 1GB ===
for file in "${LOG_FILES[@]}"; do
    for real_file in $(ls $file 2>/dev/null); do  # ls возвращает список файлов по маске
        if [ -f "$real_file" ]; then
            FILE_SIZE=$(du -b "$real_file" 2>/dev/null | cut -f1)
            if [ "$FILE_SIZE" -gt 2147483648 ]; then
                cat /dev/null > "$real_file"
                echo "Очищен: $real_file"
            fi
        fi
    done
done

# === Проверяем размер базы перед очисткой ===
if [ -d "$DB_PATH" ]; then
    DB_SIZE=$(du -sb "$DB_PATH" 2>/dev/null | cut -f1)
    if [ "$DB_SIZE" -gt "$DB_SIZE_LIMIT" ]; then
        echo "Размер базы $DB_PATH превышает 5GB ($DB_SIZE байт). Начинаем очистку..."
        systemctl stop 0g
        find "$DB_PATH" -type f -delete
        systemctl start 0g
        echo "Очистка базы и перезапуск 0g завершены"
    else
        echo "Размер базы $DB_PATH в пределах нормы ($DB_SIZE байт). Очистка не требуется."
    fi
else
    echo "Папка базы данных $DB_PATH не найдена. Пропускаем очистку."
fi

# === Добавление в cron ===
CRON_JOB="0 9 * * * for file in /var/log/syslog.1 /var/log/syslog /root/0g-storage-node/run/log/zgs.log.*; do for real_file in \$(ls \$file 2>/dev/null); do [ -f \"\$real_file\" ] && [ \$(du -b \"\$real_file\" | cut -f1) -gt 1073741824 ] && cat /dev/null > \"\$real_file\"; done; done; systemctl stop 0g && find $DB_PATH -type f -delete && systemctl start 0g"
(crontab -l 2>/dev/null | grep -v "$DB_PATH"; echo "$CRON_JOB") | crontab -
echo "Задача добавлена в cron (запуск каждый день в 9:00)"

# === Перезапуск cron (на всякий случай) ===
systemctl restart cron
echo "Cron перезапущен"

echo "=== Настройка завершена! Скрипт отработал ==="
