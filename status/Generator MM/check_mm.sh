from eth_account import Account
from bip_utils import Bip39SeedGenerator, Bip44, Bip44Coins, Bip44Changes

def get_wallet_from_mnemonic(mnemonic):
    """
    Извлекает адрес и приватный ключ из мнемонической фразы.
    """
    try:
        # Генерация seed из мнемонической фразы
        seed = Bip39SeedGenerator(mnemonic).Generate()

        # Деривация ключей с использованием стандарта BIP-44 для Ethereum
        bip44_wallet = Bip44.FromSeed(seed, Bip44Coins.ETHEREUM)
        account = bip44_wallet.Purpose().Coin().Account(0).Change(Bip44Changes.CHAIN_EXT).AddressIndex(0)

        # Получаем приватный ключ и адрес
        private_key = account.PrivateKey().Raw().ToHex()
        eth_account = Account.from_key(private_key)

        return {
            "mnemonic": mnemonic,
            "address": eth_account.address,
            "private_key": private_key
        }
    except Exception as e:
        return {"mnemonic": mnemonic, "error": str(e)}


def main():
    # Файл с мнемоническими фразами
    input_file = "mnemonics.txt"

    # Проверяем, что файл с сид-фразами существует
    try:
        with open(input_file, "r") as file:
            mnemonics = file.readlines()
    except FileNotFoundError:
        print(f"Файл {input_file} не найден. Убедитесь, что он находится в текущей директории.")
        return

    print("Проверяем мнемонические фразы...\n")
    for i, mnemonic in enumerate(mnemonics, start=1):
        mnemonic = mnemonic.strip()
        if not mnemonic:
            continue

        wallet = get_wallet_from_mnemonic(mnemonic)

        if "error" in wallet:
            print(f"{i};{mnemonic};Ошибка:{wallet['error']}")
        else:
            print(f"{i};{wallet['mnemonic']};{wallet['address']};{wallet['private_key']}")


if __name__ == "__main__":
    main()
