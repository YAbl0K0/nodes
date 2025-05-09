import sys
import subprocess
from concurrent.futures import ThreadPoolExecutor, as_completed
import random

# Установка web3 при необходимости
try:
    from web3 import Web3
except ImportError:
    print("Устанавливаем web3...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "web3"])
    from web3 import Web3

# Список RPC для Arbitrum
RPC_LIST = [
    "https://arb1.arbitrum.io/rpc",
    "https://1rpc.io/arb"  # альтернативный публичный
]

# Контракт SQD на Arbitrum
SQD_CONTRACT = Web3.to_checksum_address("0x1337420dED5ADb9980CFc35f8f2B054ea86f8aB1")

# Минимальный ABI
MIN_ABI = [
    {
        "constant": True,
        "inputs": [{"name": "account", "type": "address"}],
        "name": "balanceOf",
        "outputs": [{"name": "", "type": "uint256"}],
        "type": "function",
    }
]

def to_checksum(address):
    try:
        return Web3.to_checksum_address(address.strip())
    except:
        print(f"❌ Некорректный адрес: {address}")
        return None

def get_sqd_balance_with_retry(address):
    for rpc in RPC_LIST:
        try:
            w3 = Web3(Web3.HTTPProvider(rpc))
            if not w3.is_connected():
                continue
            contract = w3.eth.contract(address=SQD_CONTRACT, abi=MIN_ABI)
            raw = contract.functions.balanceOf(address).call()
            return round(raw / 1e18, 6)
        except Exception as e:
            if "429" in str(e) or "Too Many Requests" in str(e):
                continue  # попробовать следующий RPC
            print(f"[DEBUG] Ошибка для {address} через {rpc}: {e}")
            return 0.0
    print(f"[DEBUG] Все RPC недоступны для {address}")
    return 0.0

def check_address(addr):
    addr = to_checksum(addr)
    if not addr:
        return f"{addr};0.0"
    balance = get_sqd_balance_with_retry(addr)
    return f"{addr};{balance}"

def check_balances():
    try:
        with open("wallet_sqd.txt", "r") as f:
            addresses = [line.strip() for line in f if line.strip()]
    except FileNotFoundError:
        print("❌ Файл wallet_sqd.txt не найден.")
        return

    print("Адрес;Баланс SQD")

    with open("sqd_balances.txt", "w") as log_file:
        log_file.write("Адрес;Баланс SQD\n")

        with ThreadPoolExecutor(max_workers=10) as executor:
            futures = [executor.submit(check_address, addr) for addr in addresses]

            for future in as_completed(futures):
                result = future.result()
                print(result)
                log_file.write(result + "\n")

if __name__ == "__main__":
    check_balances()
