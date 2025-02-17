#!/bin/bash

# === Переменные ===
LOG_FILES=("/var/log/syslog" "/root/0g-storage-node/run/log/zgs.log.*")
DB_PATH="/root/.0gchain/data/tx_index.db/"
CRON_JOB="0 9 * * * for file in /var/log/syslog /var/log/auth.log /root/0g-storage-node/run/log/zgs.log.*; do [ -f \"\$file\" ] && [ \$(du -b \"\$file\" | cut -f1) -gt 1073741824 ] && cat /dev/null > \"\$file\"; done; systemctl stop 0g && find $DB_PATH -type f -delete && systemctl start 0g"

echo "=== Выполняем очистку логов и базы ==="

# === Очистка логов, если они больше 1GB ===
for file in "${LOG_FILES[@]}"; do
    if [ -f "$file" ] && [ $(du -b "$file" | cut -f1) -gt 1073741824 ]; then
        cat /dev/null > "$file"
        echo "Очищен: $file"
    fi
done

# === Остановка 0g, удаление базы, запуск 0g ===
systemctl stop 0g
find "$DB_PATH" -type f -delete
systemctl start 0g
echo "Очистка базы и перезапуск 0g завершены"

# === Добавление в cron ===
(crontab -l 2>/dev/null | grep -v "$DB_PATH"; echo "$CRON_JOB") | crontab -
echo "Задача добавлена в cron (запуск каждый день в 9:00)"

# === Перезапуск cron (на всякий случай) ===
systemctl restart cron
echo "Cron перезапущен"

echo "=== Настройка завершена! Скрипт отработал ==="
