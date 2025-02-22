#!/bin/bash

# === Переменные ===
LOG_DIR="$HOME/0g-storage-node/run/log/"
LOG_PATTERN="zgs.log.2025-*"
SYSLOG_FILES=("/var/log/syslog.1" "/var/log/syslog")
DB_PATH="$HOME/.0gchain/data/tx_index.db/"
DB_SIZE_LIMIT=5368709120  # 5GB
LOG_SIZE_LIMIT=1073741824  # 1GB

echo "=== Настраиваем cron для ежедневной очистки ==="

# === Создание cron-скрипта ===
CRON_SCRIPT="$HOME/cron_cleanup.sh"
cat << 'EOF' > "$CRON_SCRIPT"
#!/bin/bash
LOG_DIR="$HOME/0g-storage-node/run/log/"
LOG_PATTERN="zgs.log.2025-*"
SYSLOG_FILES=("/var/log/syslog.1" "/var/log/syslog")
DB_PATH="$HOME/.0gchain/data/tx_index.db/"
DB_SIZE_LIMIT=5368709120
LOG_SIZE_LIMIT=1073741824

echo "=== [$(date)] Запуск ежедневной очистки ===" >> $HOME/cleanup.log

# === Очистка syslog, если он больше 1 ГБ ===
for file in "${SYSLOG_FILES[@]}"; do
    if [ -f "$file" ]; then
        FILE_SIZE=$(stat --format="%s" "$file" 2>/dev/null)
        echo "Проверяем syslog: $file = $FILE_SIZE байт (лимит: $LOG_SIZE_LIMIT байт)" >> $HOME/cleanup.log
        if [ "$FILE_SIZE" -gt "$LOG_SIZE_LIMIT" ]; then
            echo "Очищаем $file..." >> $HOME/cleanup.log
            sudo truncate -s 0 "$file"
        fi
    fi
done

# === Очистка логов в $LOG_DIR, если они больше 1 ГБ ===
if [ -d "$LOG_DIR" ]; then
    find "$LOG_DIR" -type f -name "$LOG_PATTERN" -print0 | while IFS= read -r -d '' log_file; do
        LOG_SIZE=$(stat --format="%s" "$log_file" 2>/dev/null)
        if [ "$LOG_SIZE" -gt "$LOG_SIZE_LIMIT" ]; then
            echo "Очищаем $log_file..." >> $HOME/cleanup.log
            truncate -s 0 "$log_file"
        fi
    done
fi

# === Очистка базы данных, если превышает 5 ГБ ===
if [ -d "$DB_PATH" ]; then
    DB_SIZE=$(du -sb "$DB_PATH" 2>/dev/null | cut -f1)
    echo "Размер базы $DB_PATH: $DB_SIZE байт (лимит: $DB_SIZE_LIMIT байт)" >> $HOME/cleanup.log
    if [ "$DB_SIZE" -gt "$DB_SIZE_LIMIT" ]; then
        echo "Очистка временных файлов базы..." >> $HOME/cleanup.log
        find "$DB_PATH" -type f -name "*.tmp" -mtime +7 -delete
        echo "Очистка базы завершена." >> $HOME/cleanup.log
    fi
fi

echo "=== [$(date)] Очистка завершена ===" >> $HOME/cleanup.log
EOF

chmod +x "$CRON_SCRIPT"

# === Добавление cron, если он еще не установлен ===
if ! crontab -l 2>/dev/null | grep -q "cron_cleanup.sh"; then
    (crontab -l 2>/dev/null | grep -v "cron_cleanup.sh"; echo "0 9 * * * /bin/bash $CRON_SCRIPT >> $HOME/cleanup.log 2>&1") | crontab -
    echo "Cron-задача добавлена (ежедневный запуск в 9:00)."
else
    echo "Cron-задача уже существует. Обновление не требуется."
fi

# === Проверяем, работает ли cron, перед перезапуском ===
if systemctl is-active --quiet cron; then
    systemctl restart cron
    echo "Cron перезапущен."
else
    echo "Ошибка: cron не активен! Попытка запуска..."
    sudo systemctl start cron
fi

echo "=== Настройка завершена. Cron теперь выполняет очистку каждый день. ==="
