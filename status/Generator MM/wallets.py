from eth_account import Account
from mnemonic import Mnemonic

def generate_wallets(num_wallets):
    wallets = []
    mnemo = Mnemonic("english")
    
    for _ in range(num_wallets):
        # Генерация мнемонической фразы
        mnemonic_phrase = mnemo.generate(strength=128)
        
        # Получение приватного ключа из мнемоники
        seed = mnemo.to_seed(mnemonic_phrase)
        account = Account.from_key(Account.create().key)
        
        wallets.append({
            "mnemonic": mnemonic_phrase,
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
        print(f"  Mnemonic: {wallet['mnemonic']}")
        print(f"  Address: {wallet['address']}")
        print(f"  Private Key: {wallet['private_key']}\n")

if __name__ == "__main__":
    main()
