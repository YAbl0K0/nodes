from eth_account import Account

def generate_wallets(num_wallets):
    wallets = []
    for _ in range(num_wallets):
        account = Account.create()
        wallets.append({
            "address": account.address,
            "private_key": account.key.hex()
        })
    return wallets

def main():
    # Запрос количества кошельков у пользователя
    user_input = input("Сколько кошельков создать? (По умолчанию: 25): ").strip()

    # Используем значение по умолчанию, если пользователь оставил поле пустым
    try:
        num_wallets = int(user_input) if user_input else 25
    except ValueError:
        print("Пожалуйста, введите корректное число.")
        return

    wallets = generate_wallets(num_wallets)
    for i, wallet in enumerate(wallets, start=1):
        print(f"Wallet {i}:")
        print(f"  Address: {wallet['address']}")
        print(f"  Private Key: {wallet['private_key']}")
        print()

if __name__ == "__main__":
    main()
