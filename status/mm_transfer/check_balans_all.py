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
    "Mantle": "https://rpc.mantle.xyz",
    "OpBNB": "https://opbnb-mainnet-rpc.bnbchain.org",
    "Arbitrum": "https://arb1.arbitrum.io/rpc",
    "BNB": "https://bsc-dataseed.binance.org"
}

# Подключение к сетям
w3_networks = {name: Web3(Web3.HTTPProvider(url)) for name, url in RPC_URLS.items()}

for name, w3 in w3_networks.items():
    assert w3.is_connected(), f"Ошибка: Не удалось подключиться к сети {name}!"

def to_checksum(address):
    """Приводит адрес к checksum-формату или возвращает None при ошибке"""
    try:
        return Web3.to_checksum_address(address)
    except:
        print(f"❌ Ошибка: {address} не является корректным Ethereum-адресом.")
        return None

def get_eth_balance(network, address):
    """Получает баланс в ETH (или его эквивалента) для указанной сети"""
    address = to_checksum(address)
    if not address:
        return 0  # Если адрес некорректный, возвращаем 0
    
    try:
        balance = w3_networks[network].eth.get_balance(address)
        return w3_networks[network].from_wei(balance, 'ether')
    except Exception as e:
        print(f"Ошибка получения баланса в {network} для {address}: {e}")
        return 0

def check_balances():
    """Читает адреса из файла и выводит баланс в формате: Адрес; MNT; OpBNB; Arbitrum; BNB"""
    with open("wallet.txt", "r") as file:
        addresses = file.readlines()
    
    print("Адрес; MNT; OpBNB; Arbitrum; BNB")  # Заголовок

    for address in addresses:
        address = address.strip()
        checksum_address = to_checksum(address)

        if not checksum_address:
            print(f"{address}; 0; 0; 0; 0")
            continue

        balances = {network: get_eth_balance(network, checksum_address) for network in RPC_URLS}
        print(f"{checksum_address}; {balances['Mantle']}; {balances['OpBNB']}; {balances['Arbitrum']}; {balances['BNB']}")

if __name__ == "__main__":
    check_balances()
