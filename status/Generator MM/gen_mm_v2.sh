#!/bin/bash

set -e

# Создаём безопасную временную директорию
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR" || exit 1

# Очищаем историю, чтобы команды не сохранялись
unset HISTFILE

# Функция очистки
cleanup() {
    shred -u -z wallets.py 2>/dev/null || rm -f wallets.py
    shred -u -z wallets.txt 2>/dev/null || rm -f wallets.txt
    history -c && history -w
    rm -rf "$TMP_DIR"
    clear
}

# Устанавливаем trap
trap cleanup EXIT

# Установка зависимостей
{
    apt update -qq && apt install -y python3-venv python3-pip curl -qq
    python3 -m venv venv
    source venv/bin/activate
    python -m ensurepip --default-pip
    pip install -q eth-account mnemonic bip-utils
} &> /dev/null

# Создаём Python-скрипт
cat << 'EOF' > wallets.py
import sys
from eth_account import Account
from mnemonic import Mnemonic
from bip_utils import Bip39SeedGenerator, Bip44, Bip44Coins, Bip44Changes

def generate_wallets(num_wallets):
    mnemo = Mnemonic("english")
    wallets = []

    for _ in range(num_wallets):
        mnemonic_phrase = mnemo.generate(strength=128)
        seed = Bip39SeedGenerator(mnemonic_phrase).Generate()
        bip44_wallet = Bip44.FromSeed(seed, Bip44Coins.ETHEREUM)
        account = bip44_wallet.Purpose().Coin().Account(0).Change(Bip44Changes.CHAIN_EXT).AddressIndex(0)
        private_key = account.PrivateKey().Raw().ToHex()
        eth_account = Account.from_key(private_key)

        wallets.append(f"{mnemonic_phrase};{eth_account.address};{private_key}")

    return wallets

def main():
    if len(sys.argv) > 1 and sys.argv[1].isdigit():
        num_wallets = int(sys.argv[1])
    else:
        print("Ошибка: укажите корректное число.")
        return

    with open("wallets.txt", "w") as f:
        for wallet in generate_wallets(num_wallets):
            f.write(wallet + "\n")

if __name__ == "__main__":
    main()
EOF

# Запрос количества кошельков
echo -n "Сколько кошельков создать? (По умолчанию: 25): "
read -r num_wallets
num_wallets=${num_wallets:-25}

# Запускаем скрипт и уничтожаем результат после вывода
python wallets.py "$num_wallets"
cat wallets.txt && sleep 60
shred -u -z wallets.txt 2>/dev/null || rm -f wallets.txt
