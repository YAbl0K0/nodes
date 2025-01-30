#!/bin/bash

set -e
mkdir -p /tmp/evd_addr && cd /tmp/evd_addr

# Функция очистки
cleanup() {
    echo "Очистка всех временных файлов..."
    rm -rf /tmp/evd_addr
}

# Если скрипт прерывается (CTRL+C) или завершается с ошибкой, очищаем всё
trap cleanup ERR EXIT INT TERM

{
    apt update && apt install -y python3-venv python3-pip curl || {
        echo "Ошибка установки пакетов через apt."
        exit 1
    }
    python3 -m venv venv --without-pip
    source venv/bin/activate
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py || {
        echo "Ошибка скачивания get-pip.py."
        exit 1
    }
    python get-pip.py --quiet
    rm get-pip.py
    pip install --quiet eth-account mnemonic || {
        echo "Ошибка установки Python-зависимостей."
        exit 1
    }
} &> /dev/null

# Скачиваем wallets.py
wget https://raw.githubusercontent.com/YAbl0K0/nodes/master/status/Generator%20MM/wallets.py || {
    echo "Ошибка скачивания wallets.py."
    exit 1
}

# Запрашиваем количество кошельков у пользователя
echo -n "Сколько кошельков создать? (По умолчанию: 25): "
read num_wallets

# Если пользователь ничего не ввел, используем значение по умолчанию
num_wallets=${num_wallets:-25}

# Запускаем wallets.py с передачей параметра
python wallets.py "$num_wallets" &

# Запоминаем PID процесса
PID=$!

# Ждём 60 секунд
sleep 60

# Убиваем процесс (если всё ещё работает) и удаляем файл
kill $PID 2>/dev/null || true
rm -f wallets.py

# Чистим экран
clear

deactivate
cd ..
