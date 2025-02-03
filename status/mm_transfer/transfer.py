from web3 import Web3
import time

# Настройки сети Mantle
RPC_URL = "https://rpc.mantle.xyz"
CHAIN_ID = 5000  # Chain ID Mantle
GAS_LIMIT = 300000
GAS_PRICE_GWEI = 1

# ERC-20 контракт токена
ERC20_CONTRACT_ADDRESS = "0xF793Ac038E7688Aa3220005852836108cdDB065c"
TOKEN_DECIMALS = 18

# Подключение к Web3
w3 = Web3(Web3.HTTPProvider(RPC_URL))
assert w3.is_connected(), "Ошибка: Не удалось подключиться к сети Mantle!"

def get_token_balance(address):
    """Получает баланс токенов"""
    contract = w3.eth.contract(address=ERC20_CONTRACT_ADDRESS, abi=[
        {"constant": True, "inputs": [{"name": "", "type": "address"}], "name": "balanceOf", 
         "outputs": [{"name": "", "type": "uint256"}], "type": "function"}
    ])
    balance = contract.functions.balanceOf(address).call()
    return balance / (10 ** TOKEN_DECIMALS)

def send_tokens(private_key, sender, recipient, amount):
    """Отправляет токены"""
    contract = w3.eth.contract(address=ERC20_CONTRACT_ADDRESS, abi=[
        {"constant": False, "inputs": [{"name": "_to", "type": "address"}, {"name": "_value", "type": "uint256"}], 
         "name": "transfer", "outputs": [{"name": "", "type": "bool"}], "type": "function"}
    ])

    token_balance = get_token_balance(sender)
    if amount > token_balance:
        print(f"⚠️ Недостаточный баланс: {token_balance}. Отправка скорректирована.")
        amount = token_balance - 0.0001  # Оставляем немного для безопасности
        if amount <= 0:
            print("❌ Ошибка: недостаточно токенов для отправки.")
            return
    
    nonce = w3.eth.get_transaction_count(sender)
    token_amount = int(amount * (10 ** TOKEN_DECIMALS))

    estimated_gas = contract.functions.transfer(recipient, token_amount).estimate_gas({'from': sender}) + 10000

    tx = contract.functions.transfer(recipient, token_amount).build_transaction({
        'from': sender,
        'nonce': nonce,
        'gas': estimated_gas,
        'gasPrice': w3.eth.gas_price,  # Динамическая цена газа
        'chainId': CHAIN_ID
    })

    signed_tx = w3.eth.account.sign_transaction(tx, private_key)
    tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
    print(f"✅ Отправлено {amount} токенов: {w3.to_hex(tx_hash)}")

def main():
    """Главная функция"""
    print("Выберите действие:")
    print("1️⃣ Отправить все токены")
    print("2️⃣ Отправить 0.1 токена")
    
    choice = input("Ваш выбор (1/2): ")
    
    if choice not in ["1", "2"]:
        print("❌ Неверный ввод. Завершение работы.")
        return
    
    with open("addresses.txt", "r") as file:
        lines = file.readlines()
    
    for line in lines:
        sender, private_key, recipient = line.strip().split(";")
        
        token_balance = get_token_balance(sender)
        print(f"💰 Баланс {sender}: {token_balance} токенов")
        
        if choice == "1":
            send_tokens(private_key, sender, recipient, token_balance)  # Отправка всех токенов
        elif choice == "2":
            send_tokens(private_key, sender, recipient, 0.1)  # Отправка 0.1 токена
        
        time.sleep(3)  # Задержка между транзакциями

if __name__ == "__main__":
    main()
