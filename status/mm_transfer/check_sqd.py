import sys
import subprocess

# Встановлення Web3, якщо не встановлено
try:
    from web3 import Web3
except ImportError:
    print("Встановлюємо web3...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "web3"])
    from web3 import Web3

# 🔑 Встав сюди свій Alchemy API KEY
ALCHEMY_KEY = "CZp2sOzdTa1SZukXkVGpP0kpsyhJL5nL"
RPC_URLS = {
    "Arbitrum": f"https://arb-mainnet.g.alchemy.com/v2/{ALCHEMY_KEY}"
}

# Адреса контракту токена SQD
SQD_CONTRACT_ADDRESS = "0x1337420ded5adb9980cfc35f82b2b054ea86f8ab"

# ABI тільки з balanceOf (без decimals, бо воно не працює)
MIN_ABI = [
    {
        "inputs": [{"internalType": "address", "name": "account", "type": "address"}],
        "name": "balanceOf",
        "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function"
    }
]

# Підключення
w3 = Web3(Web3.HTTPProvider(RPC_URLS["Arbitrum"]))
assert w3.is_connected(), "❌ Не вдалося підключитись до Alchemy Arbitrum RPC!"

def to_checksum(address):
    try:
        return Web3.to_checksum_address(address)
    except:
        print(f"❌ Некоректний адрес: {address}")
        return None

def get_sqd_balance(address):
    try:
        address = to_checksum(address)
        if not address:
            return 0.0
        contract = w3.eth.contract(address=SQD_CONTRACT_ADDRESS, abi=MIN_ABI)
        raw = contract.functions.balanceOf(address).call()
        return round(raw / (10 ** 18), 3)  # SQD має 18 децималів
    except Exception as e:
        print(f"[DEBUG] Помилка для {address}: {e}")
        return 0.0

def check_sqd():
    try:
        with open("wallet.txt", "r") as file:
            addresses = [line.strip() for line in file.readlines()]
    except FileNotFoundError:
        print("Файл wallet.txt не знайдено.")
        return

    print("Адрес;SQD")
    for address in addresses:
        balance = get_sqd_balance(address)
        print(f"{address};{balance}")

if __name__ == "__main__":
    check_sqd()
