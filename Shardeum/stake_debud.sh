#!/bin/bash

# Ввод данных
read -p "Введите приватный ключ от тестнет кошелька Shardeum: " PRIVATE_KEY
read -p "Введите адрес кошелька Shardeum: " WALLET_ADDRESS

# Функция для получения текущего значения стейка
get_stake_amount() {
    local address=$1
    local output=$(docker exec -i shardeum-validator operator-cli stake_info "$address" 2>/dev/null | grep "stake:" | awk '{print $2}' | tr -d "'")
    echo "$output"
}

# Функция для выполнения команды стейкинга
run_stake_command() {
    local private_key=$1
    local stake_value=$2

    echo "Выполняется команда стейкинга на сумму: $stake_value..."
    docker exec -i shardeum-validator sh -c "(sleep 10; echo \"$private_key\"; sleep 10) | operator-cli stake $stake_value"
}

# Функция для проверки ноды и запуска стейка
stake_tokens() {
    local private_key=$1
    local wallet_address=$2
    local retries=3
    local attempt=1

    # Запускаем ноду
    echo "Запуск ноды..."
    docker exec -i shardeum-validator operator-cli start

    # Получаем начальный стейк
    local initial_stake=$(get_stake_amount "$wallet_address")
    if [[ -z "$initial_stake" ]]; then
        initial_stake=0
    fi
    echo "Текущий стейк: $initial_stake"

    # Выполняем попытки стейкинга
    while [[ $attempt -le $retries ]]; do
        echo "Попытка стейкинга #$attempt..."
        
        # Рассчитываем случайное значение стейка (от 10 до 12)
        local stake_value=$(awk "BEGIN { printf \"%.1f\", 10 + (rand() * 2) }")

        # Выполняем команду стейкинга
        run_stake_command "$private_key" "$stake_value"

        # Ждем некоторое время перед проверкой результата
        sleep $((40 + RANDOM % 50))

        # Проверяем новый стейк
        local new_stake=$(get_stake_amount "$wallet_address")
        if [[ "$new_stake" != "$initial_stake" ]]; then
            echo -e "\033[1;32mСтейкинг выполнен успешно! Текущий стейк: $new_stake\033[0m"
            return 0
        fi

        echo -e "\033[1;31mСтейкинг не удался. Попробуем снова.\033[0m"
        ((attempt++))
    done

    echo -e "\033[1;31mНе удалось выполнить стейкинг после $retries попыток.\033[0m"
    return 1
}

# Запуск процесса стейкинга
stake_tokens "$PRIVATE_KEY" "$WALLET_ADDRESS"

# Информация для пользователя
echo -e "\033[1;33mЕсли стейкинг не сработал, попробуйте запустить скрипт снова.\033[0m"
