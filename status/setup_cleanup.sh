#!/bin/bash

# === Переменные ===
LOG_DIR="$HOME/0g-storage-node/run/log/"
LOG_PATTERN="zgs.log.2025-*"
SYSLOG_FILES=("/var/log/syslog.1" "/var/log/syslog")
DB_PATH="$HOME/.0gchain/data/tx_index.db/"
DB_SIZE_LIMIT=5368709120  # 5GB
LOG_SIZE_LIMIT=1073741824  # 1GB

echo "=== Начинаем разовую очистку ==="

# === Очистка syslog, если он больше 1 ГБ ===
for file in "${SYSLOG_FILES[@]}"; do
    if [ -f "$file" ]; then
        FILE_SIZE=$(stat --format="%s" "$file" 2>/dev/null)
        echo "Проверяем syslog: $file = $FILE_SIZE байт (лимит: $LOG_SIZE_LIMIT байт)"
        if [ "$FILE_SIZE" -gt "$LOG_SIZE_LIMIT" ]; then
            echo "Очищаем $file..."
            sudo truncate -s 0 "$file"
        else
            echo "Файл $file не превышает 1 ГБ, пропускаем."
        fi
    else
        echo "Файл $file не найден, пропускаем."
    fi
done

# === Остановка 0g перед очисткой базы ===
echo "Останавливаем 0g..."
sudo systemctl stop 0g
sleep 5

if systemctl is-active --quiet 0g; then
    echo "Ошибка: процесс 0g не остановился, принудительное завершение..."
    sudo systemctl kill 0g
fi

# === Очистка базы данных, если превышает 5 ГБ ===
if [ -d "$DB_PATH" ]; then
    DB_SIZE=$(du -sb "$DB_PATH" 2>/dev/null | cut -f1)
    if [ "$DB_SIZE" -gt "$DB_SIZE_LIMIT" ]; then
        echo "Размер базы $DB_PATH ($DB_SIZE байт) превышает 5GB. Начинаем очистку..."
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
    echo "Проверяем файлы логов в $LOG_DIR..."
    find "$LOG_DIR" -type f -name "$LOG_PATTERN" -print0 | while IFS= read -r -d '' log_file; do
        LOG_SIZE=$(stat --format="%s" "$log_file" 2>/dev/null)
        echo "Найден файл: $log_file (размер: $LOG_SIZE байт)"
        if [ "$LOG_SIZE" -gt "$LOG_SIZE_LIMIT" ]; then
            echo "Очищаем $log_file..."
            truncate -s 0 "$log_file"
        else
            echo "Файл $log_file не превышает 1 ГБ, пропускаем."
        fi
    done
else
    echo "Директория логов $LOG_DIR не найдена. Пропускаем очистку."
fi

echo "=== Разовая очистка завершена. Теперь настраиваем cron. ==="

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

echo "=== [$(date)] Запуск cron очистки ===" >> $HOME/cleanup.log

if [ -d "$DB_PATH" ]; then
    DB_SIZE=$(du -sb "$DB_PATH" 2>/dev/null | cut -f1)
    if [ "$DB_SIZE" -gt "$DB_SIZE_LIMIT" ]; then
        echo "Очистка базы ($DB_SIZE байт)" >> $HOME/cleanup.log
        systemctl stop 0g
        find "$DB_PATH" -type f -name "*.tmp" -mtime +7 -delete
        systemctl start 0g
    fi
fi

if [ -d "$LOG_DIR" ]; then
    find "$LOG_DIR" -type f -name "$LOG_PATTERN" -print0 | while IFS= read -r -d '' log_file; do
        LOG_SIZE=$(stat --format="%s" "$log_file" 2>/dev/null)
        if [ "$LOG_SIZE" -gt "$LOG_SIZE_LIMIT" ]; then
            echo "Очистка $log_file ($LOG_SIZE байт)" >> $HOME/cleanup.log
            truncate -s 0 "$log_file"
        fi
    done
fi

for file in "${SYSLOG_FILES[@]}"; do
    if [ -f "$file" ]; then
        FILE_SIZE=$(stat --format="%s" "$file" 2>/dev/null)
        if [ "$FILE_SIZE" -gt "$LOG_SIZE_LIMIT" ]; then
            echo "Очистка $file ($FILE_SIZE байт)" >> $HOME/cleanup.log
            sudo truncate -s 0 "$file"
        fi
    fi
done

echo "=== [$(date)] Cron очистка завершена ===" >> $HOME/cleanup.log
EOF

chmod +x "$CRON_SCRIPT"

# === Добавление cron, если он еще не установлен ===
if ! crontab -l 2>/dev/null | grep -q "cron_cleanup.sh"; then
    (crontab -l 2>/dev/null; echo "0 9 * * * /bin/bash $CRON_SCRIPT >> $HOME/cleanup.log 2>&1") | crontab -
    echo "Задача добавлена в cron (ежедневный запуск в 9:00)."
else
    echo "Задача уже существует в cron. Повторное добавление не требуется."
fi

# === Проверяем, работает ли cron, перед перезапуском ===
if systemctl is-active --quiet cron; then
    systemctl restart cron
    echo "Cron перезапущен."
else
    echo "Ошибка: cron не активен! Попытка запуска..."
    sudo systemctl start cron
fi

echo "=== Настройка завершена. Cron теперь выполняет очистку с проверкой размера. ==="
