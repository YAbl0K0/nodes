from web3 import Web3
import time

# Настройки сети Mantle
RPC_URL = "rpc.mantle.xyz"  #RPC
CHAIN_ID = 5000  #Chain ID
GAS_LIMIT = 21000
GAS_PRICE_GWEI = 1

# ERC-20 контракт токена
ERC20_CONTRACT_ADDRESS = "0xF793Ac038E7688Aa3220005852836108cdDB065c"
TOKEN_DECIMALS = 18

# Подключение к Web3
w3 = Web3(Web3.HTTPProvider(RPC_URL))
assert w3.is_connected(), "Ошибка: Не удалось подключиться к сети!"

def get_eth_balance(address):
    balance = w3.eth.get_balance(address)
    return w3.from_wei(balance, 'ether')

def get_token_balance(address):
    contract = w3.eth.contract(address=ERC20_CONTRACT_ADDRESS, abi=[
        {"constant": True, "inputs": [{"name": "", "type": "address"}], "name": "balanceOf", "outputs": [{"name": "", "type": "uint256"}], "type": "function"}
    ])
    balance = contract.functions.balanceOf(address).call()
    return balance / (10 ** TOKEN_DECIMALS)

def send_eth(private_key, sender, recipient):
    balance = get_eth_balance(sender)
    if balance > 0:
        amount = balance - 0.0001  #запас на газ
        nonce = w3.eth.get_transaction_count(sender)
        tx = {
            'to': recipient,
            'value': w3.to_wei(amount, 'ether'),
            'gas': GAS_LIMIT,
            'gasPrice': w3.to_wei(GAS_PRICE_GWEI, 'gwei'),
            'nonce': nonce,
            'chainId': CHAIN_ID
        }
        signed_tx = w3.eth.account.sign_transaction(tx, private_key)
        tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
        print(f"Отправлено {amount} ETH: {w3.to_hex(tx_hash)}")

def send_tokens(private_key, sender, recipient, amount):
    contract = w3.eth.contract(address=ERC20_CONTRACT_ADDRESS, abi=[
        {"constant": False, "inputs": [{"name": "_to", "type": "address"}, {"name": "_value", "type": "uint256"}], "name": "transfer", "outputs": [{"name": "", "type": "bool"}], "type": "function"}
    ])
    nonce = w3.eth.get_transaction_count(sender)
    token_amount = int(amount * (10 ** TOKEN_DECIMALS))
    tx = contract.functions.transfer(recipient, token_amount).build_transaction({
        'from': sender,
        'nonce': nonce,
        'gas': 100000,
        'gasPrice': w3.to_wei(GAS_PRICE_GWEI, 'gwei'),
        'chainId': CHAIN_ID
    })
    signed_tx = w3.eth.account.sign_transaction(tx, private_key)
    tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
    print(f"Отправлено {amount} токенов: {w3.to_hex(tx_hash)}")

def main():
    choice = input("Отправить все токены (1) или 0.1 токена (2)? ")
    with open("addresses.txt", "r") as file:
        lines = file.readlines()
        
    for line in lines:
        sender, private_key, recipient = line.strip().split(";")
        
        eth_balance = get_eth_balance(sender)
        token_balance = get_token_balance(sender)
        print(f"Баланс {sender}: {eth_balance} ETH, {token_balance} токенов")
        
        send_eth(private_key, sender, recipient)  # Отправить весь ETH, оставляя запас на газ
        
        if choice == "1":
            send_tokens(private_key, sender, recipient, token_balance)  # Отправить все токены
        elif choice == "2":
            send_tokens(private_key, sender, recipient, 0.1)  # Отправить 0.1 токена
        
        time.sleep(5)  # Задержка между транзакциями

if __name__ == "__main__":
    main()
