import csv
import requests
import json
from web3 import Web3

# Подключение к RPC Arbitrum
w3 = Web3(Web3.HTTPProvider("https://arbitrum-mainnet.infura.io/v3/93ff81a0346847809ac76f699b69098c"))

# Адрес контракта и API-ключ Arbscan
CONTRACT = "0xa91fF8b606BA57D8c6638Dd8CF3FC7eB15a9c634"
API_KEY = "RVVY832DVQGA39F4IVC82615YYYIGUB1S2"

# Получение ABI контракта через API Arbscan
def get_ABI(contract):
    url = f"https://api.arbiscan.io/api?module=contract&action=getabi&address={contract}&apikey={API_KEY}"
    response = requests.get(url).json()
    return json.loads(response['result'])

# Доступ к контракту с ABI
def access_Contract(contract):
    abi = get_ABI(contract)
    return w3.eth.contract(address=contract, abi=abi)

# Выполнение multicall для одного кошелька
def multicall_for_wallet(wallet_address, private_key):
    contract = access_Contract(CONTRACT)
    
    # Данные для вызова multicall
    method_data = [
        "0xf39a19bf0000000000000000000000005990c2a11af316987d2d99fe8b813d7c1f0ba0d0"
    ]
    
    # Построение транзакции
    txn = contract.functions.multicall(method_data).build_transaction({
        'from': wallet_address,
        'gas': 600000,
        'gasPrice': w3.toWei('0.01041', 'gwei'),
        'nonce': w3.eth.getTransactionCount(wallet_address),
    })

    # Подписание транзакции
    signed_txn = w3.eth.account.sign_transaction(txn, private_key)

    # Отправка транзакции
    tx_hash = w3.eth.send_raw_transaction(signed_txn.rawTransaction)
    print(f"✅ Transaction sent for {wallet_address}. Hash: {tx_hash.hex()}")

    # Ожидание подтверждения (опционально)
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    print(f"✅ Transaction receipt for {wallet_address}: {receipt}")

# Чтение данных из CSV и выполнение multicall для каждого кошелька
def process_wallets():
    with open('wallets.csv', 'r') as file:
        reader = csv.DictReader(file)
        for row in reader:
            address = row['address'].strip()
            private_key = row['private_key'].strip()

            # Добавляем 0x, если его нет
            if not private_key.startswith("0x"):
                private_key = "0x" + private_key

            # Проверка длины приватного ключа
            if len(private_key) != 66:
                print(f"❌ Ошибка: Приватный ключ для {address} имеет неправильную длину ({len(private_key)}). Пропускаем.")
                continue

            try:
                multicall_for_wallet(address, private_key)
            except Exception as e:
                print(f"❌ Ошибка при обработке {address}: {e}")

# Запуск обработки
process_wallets()
