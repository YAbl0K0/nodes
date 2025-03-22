import sys
import subprocess

# Установка web3 при необходимости
try:
    from web3 import Web3
except ImportError:
    print("Устанавливаем web3...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "web3"])
    from web3 import Web3

# ✅ Стабильный публичный RPC Arbitrum
RPC_URL = "https://1rpc.io/arb"

# Подключение к Arbitrum
w3 = Web3(Web3.HTTPProvider(RPC_URL))
assert w3.is_connected(), "❌ Не удалось подключиться к Arbitrum RPC"

# Контракт токена SQD (в Arbitrum)
SQD_CONTRACT = "0x1337420ded5adb9980cfc35f82b2b054ea86f8ab"

# Минимальный ABI с balanceOf
MIN_ABI = [
    {
        "inputs": [{"internalType": "address", "name": "account", "type": "address"}],
        "name": "balanceOf",
        "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function"
    }
]

def to_checksum(address):
    try:
        return Web3.to_checksum_address(address)
    except:
        print(f"❌ Некорректный адрес: {address}")
        return None

def get_sqd_balance(address):
    try:
        address = to_checksum(address)
        if not address:
            return 0.0
        contract = w3.eth.contract(address=Web3.to_checksum_address(SQD_CONTRACT), abi=MIN_ABI)
        raw = contract.functions.balanceOf(address).call()
        return round(raw / (10 ** 18), 3)
    except Exception as e:
        print(f"[DEBUG] Ошибка для {address}: {e}")
        return 0.0

def check_sqd_from_file():
    try:
        with open("wallet.txt", "r") as f:
            addresses = [line.strip() for line in f if line.strip()]
    except FileNotFoundError:
        print("Файл wallet.txt не найден.")
        return

    print("Адрес;SQD")
    for addr in addresses:
        balance = get_sqd_balance(addr)
        print(f"{addr};{balance}")

if __name__ == "__main__":
    check_sqd_from_file()
