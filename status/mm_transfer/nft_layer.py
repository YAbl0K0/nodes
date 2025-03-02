
from web3 import Web3

# Настройки
RPC_URL = "https://base-mainnet.g.alchemy.com/v2/ygAB_MYqQVqYgvOdxyQVefjDW3ApX3-B"  # Замените на актуальный RPC
CONTRACT_ADDRESSES = {
    "OG Pledge Pass": "0xb06C68C8f9DE60107eAbda0D7567743967113360",
    "Standard Pledge Pass": "0xb06C68C8f9DE60107eAbda0D7567743967113360"
}

ABI = '[{"constant":true,"inputs":[{"name":"owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"}]'

# Подключение к сети
web3 = Web3(Web3.HTTPProvider(RPC_URL))

# Проверяем соединение
if not web3.is_connected():
    print("Ошибка: Нет соединения с блокчейном. Проверьте RPC.")
    exit()

# Загружаем контракты
contracts = {name: web3.eth.contract(address=Web3.to_checksum_address(addr), abi=ABI) for name, addr in CONTRACT_ADDRESSES.items()}

# Читаем список адресов
with open("wallet.txt", "r") as file:
    addresses = [line.strip() for line in file if line.strip()]

# Проверка наличия NFT
for address in addresses:
    if web3.is_address(address):
        address = Web3.to_checksum_address(address)
        balances = {name: contract.functions.balanceOf(address).call() > 0 for name, contract in contracts.items()}

        print(f"\nАдрес: {address}")
        for name, has_nft in balances.items():
            print(f"  {name}: {'Есть' if has_nft else 'Нет'}")
    else:
        print(f"Ошибка: Неверный адрес в файле - {address}")
