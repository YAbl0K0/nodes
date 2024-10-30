from eth_account import Account
from eth_account.hdaccount import generate_mnemonic
import sys

def generate_wallet():
    # Генерируем мнемоническую фразу с 12 словами на английском языке
    mnemonic = generate_mnemonic(num_words=12, language="english")
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
    # Запрос количества кошельков у пользователя
    user_input = input("Сколько кошельков создать? (По умолчанию: 25): ").strip()

    # Используем значение по умолчанию, если пользователь оставил поле пустым
    num_wallets = int(user_input) if user_input.isdigit() else 25

    wallets = generate_wallets(num_wallets)
    for wallet in wallets:
        print(f"{wallet['mnemonic']};{wallet['address']};{wallet['private_key']}")

if __name__ == "__main__":
    main()
