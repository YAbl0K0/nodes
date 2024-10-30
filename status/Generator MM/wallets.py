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
