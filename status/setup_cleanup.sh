#!/bin/bash

# === Переменные ===
LOG_DIR="$HOME/0g-storage-node/run/log/"
LOG_PATTERN="zgs.log.2025-*"
SYSLOG_FILES=("/var/log/syslog.1" "/var/log/syslog")
DB_PATH="$HOME/.0gchain/data/tx_index.db/"
DB_SIZE_LIMIT=5368709120  # 5GB
LOG_SIZE_LIMIT=1073741824  # 1GB

CRON_SCRIPT="$HOME/cron_cleanup.sh"

# === Создание cron-скрипта ===
cat << 'EOF' > "$CRON_SCRIPT"
#!/bin/bash
LOG_DIR="$HOME/0g-storage-node/run/log/"
LOG_PATTERN="zgs.log.2025-*"
SYSLOG_FILES=("/var/log/syslog.1" "/var/log/syslog")
DB_PATH="$HOME/.0gchain/data/tx_index.db/"
DB_SIZE_LIMIT=5368709120
LOG_SIZE_LIMIT=1073741824

{
  echo "=== [$(date)] Запуск ежедневной очистки ==="

  # Очистка syslog
  for file in "${SYSLOG_FILES[@]}"; do
      if [ -f "$file" ]; then
          FILE_SIZE=$(stat --format="%s" "$file" 2>/dev/null)
          if [ "$FILE_SIZE" -gt "$LOG_SIZE_LIMIT" ]; then
              sudo truncate -s 0 "$file"
              echo "Очищен syslog: $file"
          fi
      fi
  done

  # Очистка всех больших логов в /var/log
  sudo find /var/log -type f -size +1G -exec truncate -s 0 {} +

  # Очистка логов в $LOG_DIR
  if [ -d "$LOG_DIR" ]; then
      find "$LOG_DIR" -type f -name "$LOG_PATTERN" -print0 | while IFS= read -r -d '' log_file; do
          LOG_SIZE=$(stat --format="%s" "$log_file" 2>/dev/null)
          if [ "$LOG_SIZE" -gt "$LOG_SIZE_LIMIT" ]; then
              truncate -s 0 "$log_file"
              echo "Очищен лог: $log_file"
          fi
      done
  fi

  # Очистка базы данных, если превышает 5 ГБ
  if [ -d "$DB_PATH" ]; then
      DB_SIZE=$(du -sb "$DB_PATH" 2>/dev/null | cut -f1)
      if [ "$DB_SIZE" -gt "$DB_SIZE_LIMIT" ]; then
          find "$DB_PATH" -type f -name "*.tmp" -mtime +7 -delete
          echo "Очищены временные файлы базы данных."
      fi
  fi

  echo "=== [$(date)] Очистка завершена ==="
} >> "$HOME/cleanup.log" 2>&1
EOF

chmod +x "$CRON_SCRIPT"

# === Добавление cron-задачи ===
if ! crontab -l 2>/dev/null | grep -q "cron_cleanup.sh"; then
    (crontab -l 2>/dev/null; echo "0 9 * * * /bin/bash $CRON_SCRIPT") | crontab -
    echo "Cron-задача добавлена (ежедневный запуск в 9:00)."
else
    echo "Cron-задача уже существует. Обновление не требуется."
fi

# === Проверка и перезапуск cron ===
if systemctl is-active --quiet cron; then
    systemctl restart cron
    echo "Cron перезапущен."
else
    echo "Cron не активен, запуск..."
    sudo systemctl start cron
fi

# === Итоговое сообщение ===
echo "Настройка завершена. Cron теперь выполняет очистку ежедневно."
