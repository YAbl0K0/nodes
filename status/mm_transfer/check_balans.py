from web3 import Web3
import json

# RPC URL для разных сетей
RPC_URLS = {
    "Mantle": "https://rpc.mantle.xyz",
    "Arbitrum": "https://arb1.arbitrum.io/rpc",
    "Optimism": "https://mainnet.optimism.io",
    "opBNB": "https://opbnb-mainnet-rpc.bnbchain.org"
}

# Пример ERC-20 ABI (минимальный)
ERC20_ABI = json.loads("""[
    {"constant": true, "inputs": [{"name": "_owner", "type": "address"}], "name": "balanceOf", 
     "outputs": [{"name": "balance", "type": "uint256"}], "type": "function"},
    {"constant": true, "inputs": [], "name": "decimals", "outputs": [{"name": "", "type": "uint8"}], "type": "function"},
    {"constant": true, "inputs": [], "name": "symbol", "outputs": [{"name": "", "type": "string"}], "type": "function"}
]""")

# Список контрактов токенов в разных сетях (можно дополнять)
TOKEN_CONTRACTS = {
    "Mantle": ["0xF793Ac038E7688Aa3220005852836108cdDB065c"],  # Пример токена
    "Arbitrum": ["0xFF970A61A04b1cA14834A43f5De4533ebDdB5c78"],  # USDC
    "Optimism": ["0x7F5c764cBc14f9669B88837ca1490cCa17c31607"],  # USDC
    "opBNB": ["0x55d398326f99059fF775485246999027B3197955"]   # USDT
}

def to_checksum(address):
    """Приводит адрес к checksum-формату"""
    try:
        return Web3.to_checksum_address(address)
    except:
        print(f"❌ Ошибка: {address} не является корректным Ethereum-адресом.")
        return None

def get_eth_balance(w3, address):
    """Получает баланс основной валюты (ETH, MNT, BNB и т.д.)"""
    try:
        balance = w3.eth.get_balance(address)
        return w3.from_wei(balance, 'ether')
    except Exception as e:
        print(f"Ошибка получения баланса для {address}: {e}")
        return 0

def get_token_balance(w3, token_address, user_address):
    """Получает баланс конкретного токена"""
    try:
        contract = w3.eth.contract(address=token_address, abi=ERC20_ABI)
        balance = contract.functions.balanceOf(user_address).call()
        decimals = contract.functions.decimals().call()
        symbol = contract.functions.symbol().call()
        return balance / (10 ** decimals), symbol
    except Exception as e:
        print(f"Ошибка получения баланса токена {token_address} для {user_address}: {e}")
        return 0, "UNKNOWN"

def check_balances():
    """Читает адреса из файла и проверяет балансы во всех сетях"""
    with open("wallet.txt", "r") as file:
        addresses = [line.strip() for line in file]

    print("Сеть; Адрес; Баланс ETH/MNT/BNB; Токены")

    for net, rpc_url in RPC_URLS.items():
        w3 = Web3(Web3.HTTPProvider(rpc_url))
        if not w3.is_connected():
            print(f"❌ Ошибка подключения к сети {net}")
            continue

        for address in addresses:
            checksum_address = to_checksum(address)
            if not checksum_address:
                continue

            eth_balance = get_eth_balance(w3, checksum_address)
            tokens_info = []

            for token in TOKEN_CONTRACTS.get(net, []):
                balance, symbol = get_token_balance(w3, token, checksum_address)
                if balance > 0:
                    tokens_info.append(f"{balance} {symbol}")

            tokens_text = ", ".join(tokens_info) if tokens_info else "Нет токенов"
            print(f"{net}; {checksum_address}; {eth_balance}; {tokens_text}")

if __name__ == "__main__":
    check_balances()
