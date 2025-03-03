from web3 import Web3
from concurrent.futures import ThreadPoolExecutor, as_completed

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


# Функция проверки баланса NFT
def check_nft_balance(address):
    if not web3.is_address(address):
        return f"Ошибка: Неверный адрес в файле - {address}"

    address = Web3.to_checksum_address(address)
    balances = {name: int(contract.functions.balanceOf(address).call() > 0) for name, contract in contracts.items()}

    return f"{address};{balances['OG Pledge Pass']};{balances['Standard Pledge Pass']}"


# Запускаем многопоточность
MAX_THREADS = 20  # Настройте число потоков (чем больше, тем быстрее, но учитывайте лимиты RPC)
print("[Адрес;OG Pledge Pass;Standard Pledge Pass]")

with ThreadPoolExecutor(max_workers=MAX_THREADS) as executor:
    future_to_address = {executor.submit(check_nft_balance, address): address for address in addresses}

    for future in as_completed(future_to_address):
        print(future.result())
