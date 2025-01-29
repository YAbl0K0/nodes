import sys
from eth_account import Account
from mnemonic import Mnemonic

def generate_wallets(num_wallets):
    wallets = []
    mnemo = Mnemonic("english")
    
    for _ in range(num_wallets):
        # Генерация мнемонической фразы
        mnemonic_phrase = mnemo.generate(strength=128)
        
        # Получение приватного ключа из мнемоники
        account = Account.from_key(Account.create().key)
        
        wallets.append({
            "mnemonic": mnemonic_phrase,
            "address": account.address,
            "private_key": account.key.hex()
        })
    
    return wallets

def main():
    # Получение количества кошельков из аргумента командной строки
    if len(sys.argv) > 1:
        try:
            num_wallets = int(sys.argv[1])
        except ValueError:
            print("Пожалуйста, введите корректное число.")
            return
    else:
        num_wallets = 25  # Значение по умолчанию

    wallets = generate_wallets(num_wallets)
    for i, wallet in enumerate(wallets, start=1):
        print(f"Wallet {i}:")
        print(f"  Mnemonic: {wallet['mnemonic']}")
        print(f"  Address: {wallet['address']}")
        print(f"  Private Key: {wallet['private_key']}\n")

if __name__ == "__main__":
    main()
