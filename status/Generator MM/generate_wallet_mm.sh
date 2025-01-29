#!/bin/bash

set -e
mkdir -p evd_addr && cd evd_addr

{
    apt update && apt install -y python3-venv python3-pip curl
    python3 -m venv venv --without-pip
    source venv/bin/activate
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
    python get-pip.py --quiet
    rm get-pip.py
    pip install --quiet eth-account mnemonic
} &> /dev/null

# Скачиваем wallets.py
wget https://raw.githubusercontent.com/YAbl0K0/nodes/master/status/Generator%20MM/wallets.py

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
