#!/bin/bash

# Обробка помилок: якщо щось піде не так, скрипт завершиться
set -e

# Оновлюємо пакети та встановлюємо необхідні залежності
apt update && apt install -y python3-venv python3-pip curl

# Створюємо та переходимо в директорію для віртуального середовища
mkdir -p evd_addr && cd evd_addr

# Створюємо віртуальне середовище без pip
python3 -m venv venv --without-pip

# Активуємо віртуальне середовище
source venv/bin/activate

# Встановлюємо pip вручну
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
python get-pip.py --quiet
rm get-pip.py  # Видаляємо скрипт після використання

# Встановлюємо бібліотеку для генерації гаманців
pip install --quiet eth-account

# Створюємо Python-скрипт для генерації гаманців
wget 
# Запускаємо Python-скрипт для генерації гаманців
python wallets.py

# Деактивуємо віртуальне середовище
deactivate

# Повертаємося в попередню директорію
cd ..
