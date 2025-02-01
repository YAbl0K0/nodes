from web3 import Web3

# Подключение к сети Mantle
RPC_URL = "https://rpc.mantle.xyz"
w3 = Web3(Web3.HTTPProvider(RPC_URL))

# Проверка соединения
assert w3.is_connected(), "Ошибка: Не удалось подключиться к сети Mantle!"

def get_eth_balance(address):
    """Получает баланс MNT в ETH"""
    balance = w3.eth.get_balance(address)
    return w3.from_wei(balance, 'ether')

def check_balances():
    """Читает адреса из файла и выводит баланс в формате Адрес; Баланс"""
    with open("wallet.txt", "r") as file:
        addresses = file.readlines()
    
    for address in addresses:
        address = address.strip()
        eth_balance = get_eth_balance(address)
        print(f"{address}; {eth_balance}")

if __name__ == "__main__":
    check_balances()
from web3 import Web3

# Подключение к сети Mantle
RPC_URL = "https://rpc.mantle.xyz"
w3 = Web3(Web3.HTTPProvider(RPC_URL))

# Проверка соединения
assert w3.is_connected(), "Ошибка: Не удалось подключиться к сети Mantle!"

def get_eth_balance(address):
    """Получает баланс MNT в ETH"""
    balance = w3.eth.get_balance(address)
    return w3.from_wei(balance, 'ether')

def check_balances():
    """Читает адреса из файла и выводит баланс в формате Адрес; Баланс"""
    with open("wallet.txt", "r") as file:
        addresses = file.readlines()
    
    for address in addresses:
        address = address.strip()
        eth_balance = get_eth_balance(address)
        print(f"{address}; {eth_balance}; CAI {token_balance}"")

if __name__ == "__main__":
    check_balances()
