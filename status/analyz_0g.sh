# Списки для вывода
DISCONNECTED_IPS=()
NEW_IPS=()

# Файлы с известными IP
KNOWN_IP_FILE="known_ips.txt"
if [[ ! -f $KNOWN_IP_FILE ]]; then
    touch "$KNOWN_IP_FILE"
fi

# Обрабатываем каждую строку из лог-файла
while IFS= read -r LINE; do
    IP=$(echo "$LINE" | awk '{print $1}')
    LAST_SEEN=$(echo "$LINE" | awk '{print $2}')

    # Проверяем, чтобы LAST_SEEN был валидным числом
    if [[ ! "$LAST_SEEN" =~ ^[0-9]+$ ]]; then
        echo "Некорректная метка времени для IP: $IP"
        continue
    fi

    # Рассчитываем разницу времени
    TIME_DIFF=$((CURRENT_TIME - LAST_SEEN))

    # Преобразуем секунды в часы (целое число)
    TIME_DIFF_HOURS=$((TIME_DIFF / 3600))

    # Преобразуем дату последнего подключения в читаемый формат
    LAST_SEEN_DATE=$(date -d "@$(( $(date +%s) - TIME_DIFF ))" +"%Y-%m-%d")

    # Проверяем, не был ли IP активен последние 2 часа
    if (( TIME_DIFF > TWO_HOURS )); then
        DISCONNECTED_IPS+=("$TIME_DIFF_HOURS $LAST_SEEN_DATE $IP")
    fi

    # Проверяем, является ли IP новым
    if ! grep -qw "$IP" "$KNOWN_IP_FILE"; then
        echo "$IP" >> "$KNOWN_IP_FILE"
        NEW_IPS+=("$TIME_DIFF_HOURS $LAST_SEEN_DATE $IP")
    fi
done < "$LOG_FILE"

# Выводим результаты
echo "IP, не подключённые последние 2 часа:"
if [[ ${#DISCONNECTED_IPS[@]} -eq 0 ]]; then
    echo "Нет таких IP."
else
    for IP_INFO in "${DISCONNECTED_IPS[@]}"; do
        echo "$IP_INFO"
    done
fi

echo ""
echo "Новые IP:"
if [[ ${#NEW_IPS[@]} -eq 0 ]]; then
    echo "Нет новых IP."
else
    for IP_INFO in "${NEW_IPS[@]}"; do
        echo "$IP_INFO"
    done
fi
