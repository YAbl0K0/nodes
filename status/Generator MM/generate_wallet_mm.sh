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
cat << EOF > wallets.py
from eth_account import Account
from eth_account.hdaccount import generate_mnemonic
import sys

def generate_wallet():
    mnemonic = generate_mnemonic()
    account = Account.from_mnemonic(mnemonic)
    return {
        "mnemonic": mnemonic,
        "address": account.address,
        "private_key": account.key.hex()
    }

def generate_wallets(num_wallets):
    wallets = [generate_wallet() for _ in range(num_wallets)]
    return wallets

def main():
    # Запит кількості гаманців у користувача
    user_input = input("Скільки гаманців створити? (За замовчуванням: 25): ").strip()

    # Використовуємо значення за замовчуванням, якщо поле залишено порожнім
    num_wallets = int(user_input) if user_input.isdigit() else 25

    wallets = generate_wallets(num_wallets)
    for wallet in wallets:
        print(f"{wallet['mnemonic']};{wallet['address']};{wallet['private_key']}")

if __name__ == "__main__":
    main()
EOF

# Запускаємо Python-скрипт для генерації гаманців
python wallets.py

# Деактивуємо віртуальне середовище
deactivate

# Повертаємося в попередню директорію
cd ..
