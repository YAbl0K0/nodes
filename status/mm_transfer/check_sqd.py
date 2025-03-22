import sys
import subprocess

# Проверяем, установлен ли web3, и при необходимости устанавливаем
try:
    from web3 import Web3
except ImportError:
    print("web3 не найден. Устанавливаем...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "web3"])
    from web3 import Web3

# RPC-узлы для каждой сети
RPC_URLS = {
    "Arbitrum": "https://arb1.arbitrum.io/rpc",
}

# Контракт SQD на Arbitrum
SQD_CONTRACT_ADDRESS = "0x1337420ded5adb9980cfc35f82b2b054ea86f8ab"

# Минимальный ABI для токена ERC20
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

# Подключение к сетям
w3_networks = {name: Web3(Web3.HTTPProvider(url)) for name, url in RPC_URLS.items()}
for name, w3 in w3_networks.items():
    assert w3.is_connected(), f"Ошибка: Не удалось подключиться к сети {name}!"

def to_checksum(address):
    try:
        return Web3.to_checksum_address(address)
    except:
        print(f"❌ Ошибка: {address} не является корректным Ethereum-адресом.")
        return None

def get_eth_balance(network, address):
    address = to_checksum(address)
    if not address:
        return 0
    try:
        balance = w3_networks[network].eth.get_balance(address)
        balance_eth = float(w3_networks[network].from_wei(balance, 'ether'))
        return round(balance_eth, 3)
    except Exception as e:
        print(f"Ошибка получения баланса в {network} для {address}: {e}")
        return 0

def get_sqd_balance(address):
    """Получает баланс токена SQD на Arbitrum"""
    try:
        w3 = w3_networks["Arbitrum"]
        address = to_checksum(address)
        contract = w3.eth.contract(address=Web3.to_checksum_address(SQD_CONTRACT_ADDRESS), abi=MIN_ABI)

        raw_balance = contract.functions.balanceOf(address).call()
        decimals = contract.functions.decimals().call()
        return round(raw_balance / (10 ** decimals), 3)
    except Exception as e:
        print(f"[DEBUG] Ошибка SQD для {address}: {e}")
        return 0.0

def check_sqd():
    """Читает адреса и выводит только баланс SQD в Arbitrum"""
    with open("wallet.txt", "r") as file:
        addresses = file.readlines()

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
