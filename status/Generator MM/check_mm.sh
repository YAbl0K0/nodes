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
        Bip39Languages, Bip39MnemonicValidator, Bip39SeedGenerator,
        Bip44, Bip44Coins, Bip44Changes
    )
except Exception:
    sys.stderr.write("Відсутні залежності. Встановіть: pip install bip-utils eth-account\n")
    raise SystemExit(1)

def sanitize(m: str) -> str:
    """Нормалізуємо пробіли та приводимо до lower-case (BIP-39 слова нижнім регістром)."""
    return " ".join(m.strip().lower().split())

def first_word(mnemonic: str) -> str:
    """Повертає тільки перше слово мнемоніки."""
    parts = mnemonic.split()
    return parts[0] if parts else ""

def detect_language_or_raise(mnemonic: str):
    """Автовизначає мову словника BIP-39."""
    for lang in Bip39Languages:
        try:
            if Bip39MnemonicValidator(lang).IsValid(mnemonic):
                return lang
        except Exception:
            continue
    raise ValueError("Unsupported language or invalid BIP39 mnemonic")

def derive_eth_address(mnemonic: str, passphrase: str = "") -> str:
    """Деривація адреси для Ethereum з використанням BIP44 (m/44'/60'/0'/0/0)."""
    _ = detect_language_or_raise(mnemonic)
    seed = Bip39SeedGenerator(mnemonic).Generate(passphrase)
    bip44 = Bip44.FromSeed(seed, Bip44Coins.ETHEREUM)
    acct = bip44.Purpose().Coin().Account(0).Change(Bip44Changes.CHAIN_EXT).AddressIndex(0)
    priv_hex = acct.PrivateKey().Raw().ToHex()
    eth_acct = Account.from_key(bytes.fromhex(priv_hex))
    return eth_acct.address

def main(input_file="mnemonics.txt", output_file="wallets.csv"):
    with open(output_file, "w", newline="", encoding="utf-8") as out_f:
        writer = csv.writer(out_f, delimiter=';')
        writer.writerow(["first_word", "address"])
        try:
            with open(input_file, "r", encoding="utf-8") as f:
                lines = f.readlines()
        except FileNotFoundError:
            print(f"Файл {input_file} не знайдено.", file=sys.stderr)
            return

        for raw in lines:
            m = sanitize(raw)
            if not m or m.startswith("#"):
                continue
            try:
                addr = derive_eth_address(m)
                writer.writerow([first_word(m), addr])
                print(f"{first_word(m)};{addr}")
            except Exception as e:
                err = f"ERROR: {e}"
                writer.writerow([first_word(m), err])
                print(f"{first_word(m)};{err}", file=sys.stderr)

if __name__ == "__main__":
    main()
PYEOF

# Запускаємо скрипт
python3 check_wallets.py

# Безпечні права на CSV
chmod 600 wallets.csv || true

# Прибираємо тимчасовий python-скрипт
rm -f check_wallets.py

echo "Готово — результат у wallets.csv (формат: first_word;address)."
