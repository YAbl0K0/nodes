import sys
from eth_account import Account
from mnemonic import Mnemonic
from eth_keys import keys
from eth_utils import decode_hex
from hashlib import sha256

def generate_wallets(num_wallets):
    wallets = []
    mnemo = Mnemonic("english")

    for _ in range(num_wallets):
        # Генерируем мнемоническую фразу
        mnemonic_phrase = mnemo.generate(strength=128)
        
        # Создаем seed из мнемоника
        seed = mnemo.to_seed(mnemonic_phrase)

        # Берем первые 32 байта от хэша seed в качестве приватного ключа
        private_key_bytes = sha256(seed).digest()[:32]
        private_key = keys.PrivateKey(private_key_bytes)

        # Получаем Ethereum-адрес
        account = Account.from_key(private_key.to_bytes())

        wallets.append({
            "mnemonic": mnemonic_phrase,
            "address": account.address,
            "private_key": private_key.to_hex()
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
    for i, wallet in enumerate(wallets, start=1):
        print(f"Wallet {i}:")
        print(f"  Mnemonic: {wallet['mnemonic']}")
        print(f"  Address: {wallet['address']}")
        print(f"  Private Key: {wallet['private_key']}\n")

if __name__ == "__main__":
    main()
