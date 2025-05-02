import sys
import subprocess
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

# Установка web3, если не установлен
try:
    from web3 import Web3
except ImportError:
    print("web3 не найден. Устанавливаем...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "web3"])
    from web3 import Web3

# RPC для сети Shardeum
RPC_URL = "https://api.shardeum.org"
w3 = Web3(Web3.HTTPProvider(RPC_URL))

if not w3.is_connected():
    print("❌ Не удалось подключиться к RPC Shardeum!")
    sys.exit()

def to_checksum(address):
    try:
        return Web3.to_checksum_address(address.strip())
    except:
        print(f"❌ Ошибка: {address} не является корректным Ethereum-адресом.")
        return None

def get_shm_balance(address):
    try:
        time.sleep(0.5)
        balance_wei = w3.eth.get_balance(address)
        balance_shm = w3.from_wei(balance_wei, 'ether')
        return round(float(balance_shm), 6)
    except Exception as e:
        print("balance error")
        return 0.0

def check_address(address):
    checksum_address = to_checksum(address)
    if not checksum_address:
        return f"{address};ERROR"
    balance = get_shm_balance(checksum_address)
    return f"{checksum_address};{balance} SHM"

def check_all_addresses():
    try:
        with open("shm_wallet.txt", "r") as file:
            addresses = [line.strip() for line in file if line.strip()]
    except FileNotFoundError:
        print("Файл wallet.txt не найден.")
        return

    print("Адрес;Баланс SHM")
    with ThreadPoolExecutor(max_workers=2) as executor:
        futures = [executor.submit(check_address, addr) for addr in addresses]
        for future in as_completed(futures):
            print(future.result())

if __name__ == "__main__":
    check_all_addresses()
