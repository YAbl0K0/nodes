import sys
import subprocess

# Установка web3 при необхідності
try:
    from web3 import Web3
except ImportError:
    print("web3 не найден. Устанавливаем...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "web3"])
    from web3 import Web3

# RPC для Ethereum (можна замінити на Alchemy/Infura з API ключем)
RPC_URLS = {
    "Ethereum": "https://rpc.ankr.com/eth"
}

# Контракт SQD у мережі Ethereum
SQD_CONTRACT_ADDRESS = "0x1337420ded5adb9980cfc35f82b2b054ea86f8ab"

# Мінімальний ABI ERC-20 токена
MIN_ABI = [
    {
        "constant": True,
        "inputs": [{"name": "_owner", "type": "address"}],
        "name": "balanceOf",
        "outputs": [{"name": "balance", "type": "uint256"}],
        "type": "function"
    },
    {
        "constant": True,
        "inputs": [],
        "name": "decimals",
        "outputs": [{"name": "", "type": "uint8"}],
        "type": "function"
    }
]

# Підключення до Ethereum
w3_networks = {name: Web3(Web3.HTTPProvider(url)) for name, url in RPC_URLS.items()}
for name, w3 in w3_networks.items():
    assert w3.is_connected(), f"❌ Не вдалося підключитися до {name}!"

def to_checksum(address):
    try:
        return Web3.to_checksum_address(address)
    except:
        print(f"❌ Некоректний адрес: {address}")
        return None

def get_sqd_balance(address):
    """Отримує баланс SQD у Ethereum"""
    try:
        w3 = w3_networks["Ethereum"]
        address = to_checksum(address)
        if not address:
            return 0.0
        contract = w3.eth.contract(address=Web3.to_checksum_address(SQD_CONTRACT_ADDRESS), abi=MIN_ABI)
        raw_balance = contract.functions.balanceOf(address).call()
        decimals = contract.functions.decimals().call()
        return round(raw_balance / (10 ** decimals), 3)
    except Exception as e:
        print(f"[DEBUG] Помилка SQD для {address}: {e}")
        return 0.0

def check_sqd():
    """Читає адреси з wallet.txt та показує баланс SQD"""
    try:
        with open("wallet.txt", "r") as file:
            addresses = file.readlines()
    except FileNotFoundError:
        print("Файл wallet.txt не знайдено.")
        return

    print("Адрес;SQD")
    for address in addresses:
        address = address.strip()
        checksum_address = to_checksum(address)
        if not checksum_address:
            print(f"{address};0.000")
            continue
        balance = get_sqd_balance(checksum_address)
        print(f"{checksum_address};{balance}")

if __name__ == "__main__":
    check_sqd()
