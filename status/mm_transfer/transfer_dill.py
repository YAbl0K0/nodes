from web3 import Web3
import time

# Настройки сети Dill
RPC_URL = "https://rpc.dill.xyz"
CHAIN_ID = 102125  # Укажите правильный Chain ID сети Dill
GAS_LIMIT = 500000  # Базовый лимит газа
GAS_PRICE = lambda: min(max(w3.eth.gas_price, w3.to_wei(2, 'gwei')), w3.to_wei(10, 'gwei'))  # От 2 до 10 Gwei

# ERC-20 контракт токена (замените на актуальный адрес токена в сети Dill)
ERC20_CONTRACT_ADDRESS = "0xYourDillTokenAddressHere"
TOKEN_DECIMALS = 18

# Подключение к Web3
w3 = Web3(Web3.HTTPProvider(RPC_URL))
assert w3.is_connected(), "Ошибка: Не удалось подключиться к сети Dill!"

def get_eth_balance(address):
    """Получает баланс нативного токена (DILL) на адресе"""
    return w3.eth.get_balance(address)

def get_token_balance(address):
    """Получает баланс токенов и округляет до целого числа"""
    checksum_address = w3.to_checksum_address(address)  # Преобразование в checksum
    contract = w3.eth.contract(address=ERC20_CONTRACT_ADDRESS, abi=[
        {"constant": True, "inputs": [{"name": "", "type": "address"}], "name": "balanceOf", 
         "outputs": [{"name": "", "type": "uint256"}], "type": "function"}
    ])
    balance = contract.functions.balanceOf(checksum_address).call()
    return balance // (10 ** TOKEN_DECIMALS)  # Округление до целого

def send_tokens(private_key, sender, recipient):
    """Отправляет все доступные токены"""
    token_balance = get_token_balance(sender)
    eth_balance = get_eth_balance(sender)
    eth_balance_ether = w3.from_wei(eth_balance, 'ether')

    if token_balance <= 0:
        print(f"⚠️ Пропускаем отправку {sender}, так как баланс 0 токенов")
        return
    
    gas_price = GAS_PRICE()
    estimated_gas_cost = GAS_LIMIT * gas_price
    required_eth = w3.from_wei(estimated_gas_cost, 'ether')
    
    if eth_balance < estimated_gas_cost:
        print(f"❌ Недостаточно DILL для газа! Баланс: {eth_balance_ether} DILL, требуется: {required_eth} DILL. Пропускаем {sender}")
        return
    
    contract = w3.eth.contract(address=ERC20_CONTRACT_ADDRESS, abi=[
        {"constant": False, "inputs": [{"name": "_to", "type": "address"}, {"name": "_value", "type": "uint256"}], 
         "name": "transfer", "outputs": [{"name": "", "type": "bool"}], "type": "function"}
    ])
    
    nonce = w3.eth.get_transaction_count(sender)
    token_amount = token_balance * (10 ** TOKEN_DECIMALS)
    
    try:
        estimated_gas = contract.functions.transfer(recipient, token_amount).estimate_gas({'from': sender})
        tx = contract.functions.transfer(recipient, token_amount).build_transaction({
            'from': sender,
            'nonce': nonce,
            'gas': estimated_gas,
            'gasPrice': gas_price,
            'chainId': CHAIN_ID
        })
        signed_tx = w3.eth.account.sign_transaction(tx, private_key)
        tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
        print(f"✅ Отправлено {token_balance} токенов: {w3.to_hex(tx_hash)}")
    except Exception as e:
        print(f"❌ Ошибка при отправке с {sender}: {str(e)}")
        return

def main():
    """Главная функция"""
    with open("addresses.txt", "r") as file:
        lines = file.readlines()
    
    for line in lines:
        try:
            sender, private_key, recipient = line.strip().split(";")
            
            # Преобразование всех адресов в checksum
            sender = w3.to_checksum_address(sender)
            recipient = w3.to_checksum_address(recipient)
            
            token_balance = get_token_balance(sender)
            print(f"💰 Баланс {sender}: {token_balance} токенов")
            send_tokens(private_key, sender, recipient)  # Отправка всех токенов
            
            time.sleep(3)  # Задержка между транзакциями
        except Exception as e:
            print(f"⚠️ Пропущен адрес {line.strip()} из-за ошибки: {str(e)}")
            continue

if __name__ == "__main__":
    main()
