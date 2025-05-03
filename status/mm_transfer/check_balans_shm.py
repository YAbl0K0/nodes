import sys
import subprocess
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

# Установка web3, если не установлен
try:
    from web3 import Web3
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "web3"])
    from web3 import Web3

# RPC для сети Shardeum
RPC_URL = "https://api.shardeum.org"
w3 = Web3(Web3.HTTPProvider(RPC_URL))

if not w3.is_connected():
    with open("shm_results.txt", "a") as log_file:
        log_file.write("❌ Не удалось подключиться к RPC Shardeum!\n")
    sys.exit()

def to_checksum(address):
    try:
        return Web3.to_checksum_address(address.strip())
    except:
        with open("shm_results.txt", "a") as log_file:
            log_file.write(f"❌ Ошибка: {address} не является корректным Ethereum-адресом.\n")
        return None

def get_shm_balance(address):
    try:
        time.sleep(1)
        balance_wei = w3.eth.get_balance(address)
        balance_shm = w3.from_wei(balance_wei, 'ether')
        return round(float(balance_shm), 6)
    except Exception:
        with open("shm_results.txt", "a") as log_file:
            log_file.write(f"balance error for {address}\n")
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
        with open("shm_results.txt", "a") as log_file:
            log_file.write("Файл shm_wallet.txt не найден.\n")
        return

    with open("shm_results.txt", "a") as log_file:
        log_file.write("Адрес;Баланс SHM\n")
        with ThreadPoolExecutor(max_workers=1) as executor:
            futures = [executor.submit(check_address, addr) for addr in addresses]
            for future in as_completed(futures):
                log_file.write(future.result() + "\n")

if __name__ == "__main__":
    check_all_addresses()
