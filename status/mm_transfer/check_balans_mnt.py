from web3 import Web3

# Подключение к сети Mantle
RPC_URL = "https://rpc.mantle.xyz"
ERC20_CONTRACT_ADDRESS = "0xF793Ac038E7688Aa3220005852836108cdDB065c"  # Контракт токена
TOKEN_DECIMALS = 18  # Количество десятичных знаков токена

# Устанавливаем соединение с RPC
w3 = Web3(Web3.HTTPProvider(RPC_URL))
assert w3.is_connected(), "Ошибка: Не удалось подключиться к сети Mantle!"

def get_eth_balance(address):
    """Получает баланс MNT (ETH)"""
    try:
        balance = w3.eth.get_balance(address)
        return w3.from_wei(balance, 'ether')
    except Exception as e:
        print(f"Ошибка получения MNT для {address}: {e}")
        return 0

def get_token_balance(address):
    """Получает баланс токенов"""
    try:
        contract = w3.eth.contract(address=ERC20_CONTRACT_ADDRESS, abi=[
            {"constant": True, "inputs": [{"name": "", "type": "address"}], "name": "balanceOf",
             "outputs": [{"name": "", "type": "uint256"}], "type": "function"}
        ])
        balance = contract.functions.balanceOf(address).call()
        return balance / (10 ** TOKEN_DECIMALS)
    except Exception as e:
        print(f"Ошибка получения токенов для {address}: {e}")
        return 0

def check_balances():
    """Читает адреса из файла и выводит баланс в формате Адрес; Баланс MNT; Баланс Токенов"""
    with open("wallet.txt", "r") as file:
        addresses = file.readlines()
    
    print("Адрес; Баланс MNT; Баланс Токенов")  # Заголовок

    for address in addresses:
        address = address.strip()
        eth_balance = get_eth_balance(address)
        token_balance = get_token_balance(address)  # Теперь всегда определена!
        print(f"{address}; {eth_balance}; CAI {token_balance}")

if __name__ == "__main__":
    check_balances()
