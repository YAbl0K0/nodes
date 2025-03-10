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
    rm -rf "$TMP_DIR"
    clear
}

# Устанавливаем trap на прерывание или ошибку
trap cleanup ERR EXIT INT TERM

# Установка зависимостей (скрываем вывод)
{
    apt update -qq && apt install -y python3-venv python3-pip curl -qq
    python3 -m venv venv --without-pip
    source venv/bin/activate
    curl -s https://bootstrap.pypa.io/get-pip.py -o get-pip.py
    python get-pip.py -q
    rm get-pip.py
    pip install -q eth-account mnemonic bip-utils
} &> /dev/null

# Создаём Python-скрипт для генерации кошельков
cat << 'EOF' > wallets.py
import sys
from eth_account import Account
from mnemonic import Mnemonic
from bip_utils import Bip39SeedGenerator, Bip44, Bip44Coins, Bip44Changes

def generate_wallets(num_wallets):
    wallets = []
    mnemo = Mnemonic("english")

    for _ in range(num_wallets):
        # Генерируем мнемоническую фразу
        mnemonic_phrase = mnemo.generate(strength=128)

        # Генерируем seed из мнемоники
        seed = Bip39SeedGenerator(mnemonic_phrase).Generate()

        # Деривация ключей с использованием стандарта BIP-44 для Ethereum
        bip44_wallet = Bip44.FromSeed(seed, Bip44Coins.ETHEREUM)
        account = bip44_wallet.Purpose().Coin().Account(0).Change(Bip44Changes.CHAIN_EXT).AddressIndex(0)

        # Получаем приватный ключ и адрес
        private_key = account.PrivateKey().Raw().ToHex()
        eth_account = Account.from_key(private_key)

        wallets.append({
            "mnemonic": mnemonic_phrase,
            "address": eth_account.address,
            "private_key": private_key
        })

    return wallets

def main():
    # Проверяем, был ли передан аргумент для количества кошельков
    if len(sys.argv) > 1:
        try:
            num_wallets = int(sys.argv[1])
        except ValueError:
            print("Пожалуйста, введите корректное число.")
            return
    else:
        print("Ошибка: укажите количество кошельков в аргументах.")
        return

    wallets = generate_wallets(num_wallets)
    for wallet in wallets:
        print(f"{wallet['mnemonic']};{wallet['address']};{wallet['private_key']}")

if __name__ == "__main__":
    main()
EOF

# Запрашиваем количество кошельков
echo -n "Сколько кошельков создать? (По умолчанию: 25): "
read num_wallets

# Используем значение по умолчанию, если пользователь ничего не ввёл
num_wallets=${num_wallets:-25}

# Запускаем wallets.py и выводим результат
clear
python wallets.py "$num_wallets"

# Ждём 60 секунд, затем очищаем экран
sleep 60

rm -f wallet.py

# Очистка временных файлов и экрана
cleanup
