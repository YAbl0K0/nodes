import sys
import subprocess
from concurrent.futures import ThreadPoolExecutor, as_completed

# Установка web3 при необходимости
try:
    from web3 import Web3
except ImportError:
    print("Устанавливаем web3...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "web3"])
    from web3 import Web3

# RPC для сети Arbitrum
RPC_URL = "https://arb1.arbitrum.io/rpc"
w3 = Web3(Web3.HTTPProvider(RPC_URL))
assert w3.is_connected(), "❌ Не удалось подключиться к RPC Arbitrum"

# Адрес контракта токена SQD (ERC-20)
SQD_CONTRACT = Web3.to_checksum_address("0x1337420dED5ADb9980CFc35f8f2B054ea86f8aB1")

# Минимальный ABI для получения баланса
MIN_ABI = [
    {
        "constant": True,
        "inputs": [{"name": "account", "type": "address"}],
        "name": "balanceOf",
        "outputs": [{"name": "", "type": "uint256"}],
        "type": "function",
    }
]

# Преобразование адреса к checksum
def to_checksum(address):
    try:
        return Web3.to_checksum_address(address.strip())
    except:
        print(f"❌ Некорректный адрес: {address}")
        return None

# Получить баланс SQD по адресу
def get_sqd_balance(address):
    try:
        address = to_checksum(address)
        if not address:
            return 0.0
        contract = w3.eth.contract(address=SQD_CONTRACT, abi=MIN_ABI)
        raw = contract.functions.balanceOf(address).call()
        return round(raw / 1e18, 6)
    except Exception as e:
        print(f"[DEBUG] Ошибка для {address}: {e}")
        return 0.0

# Обработка одного адреса
def check_address(addr):
    balance = get_sqd_balance(addr)
    return f"{addr};{balance}"

# Основная функция: чтение адресов и запуск проверки
def check_balances():
    try:
        with open("wallet.txt", "r") as f:
            addresses = [line.strip() for line in f if line.strip()]
    except FileNotFoundError:
        print("❌ Файл wallet.txt не найден.")
        return

    print("Адрес;Баланс SQD")

    with open("sqd_balances.txt", "w") as log_file:
        log_file.write("Адрес;Баланс SQD\n")

        with ThreadPoolExecutor(max_workers=50) as executor:
            futures = [executor.submit(check_address, addr) for addr in addresses]

            for future in as_completed(futures):
                result = future.result()
                print(result)
                log_file.write(result + "\n")

if __name__ == "__main__":
    check_balances()
