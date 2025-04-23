import sys
import subprocess
from web3 import Web3
from concurrent.futures import ThreadPoolExecutor, as_completed

# Установка web3, если не установлен
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
    "BNB": "https://bsc-dataseed.binance.org",
    "Dill": "https://rpc-alps.dill.xyz"
}

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
    try:
        balance = w3_networks[network].eth.get_balance(address)
        return round(float(w3_networks[network].from_wei(balance, 'ether')), 3)
    except Exception as e:
        print(f"Ошибка получения баланса в {network} для {address}: {e}")
        return 0

def check_address_balances(address, networks):
    address = address.strip()
    checksum_address = to_checksum(address)
    if not checksum_address:
        return f"{address};" + ";".join(["0.000"] * len(networks))
    balances = [str(get_eth_balance(net, checksum_address)) for net in networks]
    return f"{checksum_address};" + ";".join(balances)

def check_balances():
    with open("wallet.txt", "r") as file:
        addresses = file.readlines()

    print("Выберите сеть для вывода баланса:")
    print("1 - Все сети")
    for i, network in enumerate(RPC_URLS.keys(), start=2):
        print(f"{i} - {network}")
    
    choice = input("Введите номер сети: ")

    if choice == "1":
        selected_networks = list(RPC_URLS.keys())
    else:
        try:
            index = int(choice) - 2
            selected_networks = [list(RPC_URLS.keys())[index]]
        except (ValueError, IndexError):
            print("Некорректный ввод. Выводим балансы по всем сетям.")
            selected_networks = list(RPC_URLS.keys())

    print("Адрес;" + ";".join(selected_networks))

    with ThreadPoolExecutor(max_workers=100) as executor:
        futures = [executor.submit(check_address_balances, addr, selected_networks) for addr in addresses]
        for future in as_completed(futures):
            print(future.result())

if __name__ == "__main__":
    check_balances()
