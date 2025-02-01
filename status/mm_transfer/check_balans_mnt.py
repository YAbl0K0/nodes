from web3 import Web3

# Настройки сети Mantle
RPC_URL = "https://rpc.mantle.xyz"
ERC20_CONTRACT_ADDRESS = "0xF793Ac038E7688Aa3220005852836108cdDB065c"
TOKEN_DECIMALS = 18

# Подключение к Web3
w3 = Web3(Web3.HTTPProvider(RPC_URL))
assert w3.is_connected(), "Ошибка: Не удалось подключиться к сети Mantle!"

def get_eth_balance(address):
    """Получает баланс MNT"""
    balance = w3.eth.get_balance(address)
    return w3.from_wei(balance, 'ether')

def get_token_balance(address):
    """Получает баланс токенов"""
    contract = w3.eth.contract(address=ERC20_CONTRACT_ADDRESS, abi=[
        {"constant": True, "inputs": [{"name": "", "type": "address"}], "name": "balanceOf", "outputs": [{"name": "", "type": "uint256"}], "type": "function"}
    ])
    balance = contract.functions.balanceOf(address).call()
    return balance / (10 ** TOKEN_DECIMALS)

def check_balances():
    """Читает адреса из файла и проверяет баланс"""
    with open("wallet.txt", "r") as file:
        addresses = file.readlines()
    
    for address in addresses:
        address = address.strip()
        eth_balance = get_eth_balance(address)
        token_balance = get_token_balance(address)
        print(f"{address}\n   MNT: {eth_balance}")

if __name__ == "__main__":
    check_balances()
