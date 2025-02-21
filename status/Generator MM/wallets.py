import sys
from mnemonic import Mnemonic
from bip_utils import Bip39SeedGenerator, Bip44, Bip44Coins, Bip44Changes
from eth_account import Account

def generate_wallets(num_wallets):
    wallets = []
    mnemo = Mnemonic("english")

    for _ in range(num_wallets):
        # Генерируем мнемоническую фразу
        mnemonic_phrase = mnemo.generate(strength=128)
        
        # Генерируем seed из мнемоники
        seed = Bip39SeedGenerator(mnemonic_phrase).Generate()

        # Деривация ключей с использованием стандарта BIP-44 для Ethereum
        bip44_wallet = Bip44.FromSeed(seed, Bip44Coins.ETHEREUM)
        account = bip44_wallet.Purpose().Coin().Account(0).Change(Bip44Changes.CHAIN_EXT).AddressIndex(0)

        # Получаем приватный ключ и адрес
        private_key = account.PrivateKey().Raw().ToHex()
        eth_account = Account.from_key(private_key)

        wallets.append({
            "mnemonic": mnemonic_phrase,
            "address": eth_account.address,
            "private_key": private_key
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
