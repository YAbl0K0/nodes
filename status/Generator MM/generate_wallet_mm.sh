#!/bin/bash

set -e

# Указываем временную директорию
TMP_DIR="/tmp/evd_addr"

# Проверяем доступность /tmp
if [ ! -d /tmp ] || [ ! -w /tmp ]; then
    echo "Ошибка: директория /tmp недоступна для записи."
    exit 1
fi

# Создаём временную папку
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

# Функция очистки
cleanup() {
    echo "Очистка временных файлов..."
    rm -rf "$TMP_DIR"
}

# Устанавливаем trap на прерывание или ошибку
trap cleanup ERR EXIT INT TERM

# Установка зависимостей
apt update && apt install -y python3-venv python3-pip curl

# Создание виртуального окружения
python3 -m venv venv --without-pip
source venv/bin/activate

# Установка pip
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
python get-pip.py
rm get-pip.py

# Установка Python-зависимостей
pip install eth-account mnemonic

# Скачиваем wallets.py
wget https://raw.githubusercontent.com/YAbl0K0/nodes/master/status/Generator%20MM/wallets.py

# Запрашиваем количество кошельков
echo -n "Сколько кошельков создать? (По умолчанию: 25): "
read num_wallets

# Используем значение по умолчанию, если пользователь ничего не ввёл
num_wallets=${num_wallets:-25}

# Запускаем wallets.py
python wallets.py "$num_wallets"

# Удаляем временные файлы
rm -f wallets.py

# Деактивация виртуального окружения
deactivate

# Очистка временной директории
cleanup
