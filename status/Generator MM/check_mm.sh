#!/usr/bin/env bash
set -euo pipefail

# Файл з мнемоніками (по одній фразі на рядок)
MNEMONIC_FILE="mnemonics.txt"
OUT_FILE="wallets.csv"

if [[ ! -f "$MNEMONIC_FILE" ]]; then
  echo "Ошибка: файл $MNEMONIC_FILE не знайдено. Створіть файл з сид-фразами по одній в рядку."
  exit 1
fi

# Створюємо тимчасовий python-скрипт
cat > check_wallets.py << 'PYEOF'
#!/usr/bin/env python3
import csv
import sys

try:
    from eth_account import Account
    from bip_utils import (
        Bip39MnemonicValidator,
        Bip39SeedGenerator,
        Bip44, Bip44Coins, Bip44Changes
    )
except Exception as e:
    sys.stderr.write("Відсутні залежності. Встановіть: pip install bip-utils eth-account\n")
    raise SystemExit(1)

def sanitize(m: str) -> str:
    """Нормалізуємо пробіли в рядку мнемоніки."""
    return " ".join(m.strip().split())

def first_three_words(mnemonic: str) -> str:
    """Повертає перші 3 слова мнемоніки (для безпечного логування)."""
    parts = mnemonic.split()
    return " ".join(parts[:3]) if parts else ""

def derive_eth_address(mnemonic: str, passphrase: str = "") -> str:
    """
    Деривація адреси для Ethereum з використанням BIP44 (m/44'/60'/0'/0/0).
    Повертає адресу у форматі 0x...
    (Приватний ключ НЕ повертається і не виводиться)
    """
    # Валідація BIP39
    if not Bip39MnemonicValidator(mnemonic).Validate():
        raise ValueError("Невалідна BIP39 мнемоніка")

    seed = Bip39SeedGenerator(mnemonic).Generate(passphrase)
    bip44 = Bip44.FromSeed(seed, Bip44Coins.ETHEREUM)
    acct = bip44.Purpose().Coin().Account(0).Change(Bip44Changes.CHAIN_EXT).AddressIndex(0)

    priv_hex = acct.PrivateKey().Raw().ToHex()  # hex без '0x'
    # Безпечно передаємо bytes до eth_account
    eth_acct = Account.from_key(bytes.fromhex(priv_hex))
    return eth_acct.address

def main(input_file="mnemonics.txt", output_file="wallets.csv"):
    with open(output_file, "w", newline="", encoding="utf-8") as out_f:
        writer = csv.writer(out_f, delimiter=';')
        writer.writerow(["index", "first_3_words", "address"])
        try:
            with open(input_file, "r", encoding="utf-8") as f:
                lines = f.readlines()
        except FileNotFoundError:
            print(f"Файл {input_file} не знайдено.", file=sys.stderr)
            return

        for i, raw in enumerate(lines, start=1):
            m = sanitize(raw)
            if not m or m.startswith("#"):
                continue
            try:
                addr = derive_eth_address(m)
                writer.writerow([i, first_three_words(m), addr])
                # також виводимо в stdout лише індекс і адресу (для зручності)
                print(f"{i};{first_three_words(m)};{addr}")
            except Exception as e:
                err = f"ERROR: {e}"
                writer.writerow([i, first_three_words(m), err])
                print(f"{i};{first_three_words(m)};{err}", file=sys.stderr)

if __name__ == "__main__":
    main()
PYEOF

# Запускаємо скрипт (вивід — адреси; приватні ключі не виводяться)
python3 check_wallets.py

# Даємо безпечні права на CSV (тільки для власника)
chmod 600 wallets.csv || true

# Видаляємо тимчасовий python-скрипт
rm -f check_wallets.py

echo "Готово — результат у wallets.csv (формат: index;first_3_words;address)."
