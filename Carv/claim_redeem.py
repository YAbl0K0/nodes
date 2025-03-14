import requests
import json
import time
from web3 import Web3

# Подключение к RPC Arbitrum
w3 = Web3(Web3.HTTPProvider("https://arbitrum-mainnet.infura.io/v3/93ff81a0346847809ac76f699b69098c"))

# Адрес контракта и API-ключ Arbscan
CONTRACT = "0xa91fF8b606BA57D8c6638Dd8CF3FC7eB15a9c634"
API_KEY = "RVVY832DVQGA39F4IVC82615YYYIGUB1S2"

# Ваш приватный ключ
PRIVATE_KEY = "2a0afc123b6d48e120be2ee443a25ff1649e4049d648e044c2937e576af0b0ae"
ACCOUNT = w3.eth.account.privateKeyToAccount(PRIVATE_KEY)

# Получение ABI контракта через API Arbscan
def get_ABI(contract):
    url = f"https://api.arbiscan.io/api?module=contract&action=getabi&address={contract}&apikey={API_KEY}"
    response = requests.get(url).json()
    return json.loads(response['result'])

# Доступ к контракту с ABI
def access_Contract(contract):
    abi = get_ABI(contract)
    return w3.eth.contract(address=contract, abi=abi)

# Выполнение multicall
def multicall():
    contract = access_Contract(CONTRACT)
    
    # Данные для вызова multicall
    method_data = [
        "0xf39a19bf0000000000000000000000005990c2a11af316987d2d99fe8b813d7c1f0ba0d0"
    ]
    
    # Построение транзакции
    txn = contract.functions.multicall(method_data).build_transaction({
        'from': ACCOUNT.address,
        'gas': 600000,
        'gasPrice': w3.toWei('0.01041', 'gwei'),
        'nonce': w3.eth.getTransactionCount(ACCOUNT.address),
    })

    # Подписание транзакции
    signed_txn = w3.eth.account.sign_transaction(txn, PRIVATE_KEY)
    
    # Отправка транзакции
    tx_hash = w3.eth.send_raw_transaction(signed_txn.rawTransaction)
    
    print(f"Transaction sent. Hash: {tx_hash.hex()}")
    
    # Ожидание получения подтверждения (опционально)
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    print("Transaction receipt:", receipt)

# Вызов функции
multicall()
