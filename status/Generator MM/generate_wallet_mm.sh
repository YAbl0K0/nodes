#!/bin/bash

pip install --quiet mnemonic

set -e
mkdir -p evd_addr && cd evd_addr

{
    apt update && apt install -y python3-venv python3-pip curl
    python3 -m venv venv --without-pip
    source venv/bin/activate
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
    python get-pip.py --quiet
    rm get-pip.py
    pip install --quiet eth-account
} &> /dev/null  # Скрываем вывод всех команд

# Отображаем только загрузку wget
wget https://raw.githubusercontent.com/YAbl0K0/nodes/master/status/Generator%20MM/wallets.py

# Показываем вывод wallets.py
python wallets.py &

# Запоминаем PID процесса
PID=$!

# Ждем 60 секунд, затем убиваем процесс (если он все еще выполняется) и удаляем файл
sleep 60
kill $PID 2>/dev/null || true  # Без ошибки, если процесс уже завершился
rm -f wallets.py

deactivate
cd ..
