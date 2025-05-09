import sys
import subprocess

# Установка web3, если не установлен
try:
    from web3 import Web3
except ImportError:
    print("Устанавливаем web3...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "web3"])
    from web3 import Web3

# RPC Arbitrum
RPC_URL = "https://arb1.arbitrum.io/rpc"
w3 = Web3(Web3.HTTPProvider(RPC_URL))
assert w3.is_connected(), "❌ Не удалось подключиться к RPC Arbitrum"

# SQD контракт (ERC-20 на Arbitrum)
SQD_CONTRACT = Web3.to_checksum_address("0x1337420dED5ADb9980CFc35f8f2B054ea86f8aB1")

# Минимальный ABI для чтения баланса
MIN_ABI = [
    {
        "constant": True,
        "inputs": [{"name": "account", "type": "address"}],
        "name": "balanceOf",
        "outputs": [{"name": "", "type": "uint256"}],
        "type": "function",
    }
]

# Функция проверки адреса
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
        return round(raw / 1e18, 6)  # шесть знаков после запятой
    except Exception as e:
        print(f"[DEBUG] Ошибка для {address}: {e}")
        return 0.0

# Чтение адресов из файла и вывод балансов
def check_balances():
    try:
        with open("wallet_sqd.txt", "r") as f:
            addresses = [line.strip() for line in f if line.strip()]
    except FileNotFoundError:
        print("❌ Файл wallet.txt не найден.")
        return

    print("Адрес;Баланс SQD")
    for addr in addresses:
        balance = get_sqd_balance(addr)
        print(f"{addr};{balance}")

if __name__ == "__main__":
    check_balances()
