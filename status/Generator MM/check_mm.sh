#!/bin/bash
set -euo pipefail

MNEMONIC_FILE="mnemonics.txt"
OUT_FILE="wallets.csv"

if [[ ! -f "$MNEMONIC_FILE" ]]; then
  echo "Ошибка: файл $MNEMONIC_FILE не найден. По одной сид-фразе на строку."
  exit 1
fi

# Создаём Python-скрипт
cat > check_wallets.py << 'EOF'
import argparse
import csv
import os
import sys

try:
    from eth_account import Account
    from bip_utils import (
        Bip39MnemonicValidator, Bip39SeedGenerator,
        Bip44, Bip44Coins, Bip44Changes
    )
except ImportError as e:
    sys.stderr.write(
        "Отсутствуют зависимости. Установите:\n"
        "  pip install bip-utils eth-account\n"
    )
    sys.exit(1)

def sanitize_mnemonic(s: str) -> str:
    # Нормализуем пробелы, убираем лишние
    return " ".join(s.strip().split())

def derive_eth_wallet(mnemonic: str, passphrase: str | None = None):
    # Валидация BIP39
    if not Bip39MnemonicValidator(mnemonic).Validate():
        raise ValueError("Невалидная BIP39 мнемоника")
    # Seed (учитываем опциональную BIP39 passphrase)
    seed_gen = Bip39SeedGenerator(mnemonic)
    seed = seed_gen.Generate(passphrase if passphrase else "")

    # Деривация по m/44'/60'/0'/0/0
    bip44 = Bip44.FromSeed(seed, Bip44Coins.ETHEREUM)
    acct = bip44.Purpose().Coin().Account(0).Change(Bip44Changes.CHAIN_EXT).AddressIndex(0)

    priv_hex = acct.PrivateKey().Raw().ToHex()        # без 0x
    # Safer: подать bytes в eth_account
    eth_acct = Account.from_key(bytes.fromhex(priv_hex))
    addr = eth_acct.address
    return addr, priv_hex

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", default="mnemonics.txt")
    parser.add_argument("--output", default="wallets.csv")
    parser.add_argument("--show-privkeys", action="store_true",
                        help="Выводить приватные ключи в CSV (ОПАСНО)")
    parser.add_argument("--passphrase", default=None,
                        help="Опциональная BIP39 passphrase")
    args = parser.parse_args()

    # Готовим writer
    out_exists = os.path.exists(args.output)
    with open(args.output, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, delimiter=';')
        header = ["index", "mnemonic", "address"]
        if args.show_privkeys:
            header.append("private_key")
        writer.writerow(header)

        try:
            with open(args.input, "r", encoding="utf-8") as infile:
                lines = infile.readlines()
        except FileNotFoundError:
            print(f"Файл {args.input} не найден.")
            sys.exit(1)

        for i, raw in enumerate(lines, start=1):
            m = sanitize_mnemonic(raw)
            if not m or m.startswith("#"):
                continue
            try:
                addr, pk = derive_eth_wallet(m, args.passphrase)
                row = [i, m, addr]
                if args.show_privkeys:
                    row.append(pk)
                writer.writerow(row)
                print(f"{i}: {addr}")
            except Exception as e:
                writer.writerow([i, m, f"ERROR: {e}"])
                print(f"{i}: ERROR: {e}", file=sys.stderr)

    # Права 600 на CSV
    try:
        os.chmod(args.output, 0o600)
    except Exception:
        pass

if __name__ == "__main__":
    main()
EOF

# Запуск (по умолчанию без приватников)
python3 check_wallets.py --input "$MNEMONIC_FILE" --output "$OUT_FILE"

# Удаляем временный скрипт
rm -f check_wallets.py

echo "Готово: $OUT_FILE (права 600). В stdout выведены только адреса."
