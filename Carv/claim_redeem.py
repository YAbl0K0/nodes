import csv
import json
from web3 import Web3

# Подключение к RPC Arbitrum
w3 = Web3(Web3.HTTPProvider("https://arbitrum-mainnet.infura.io/v3/YOUR_INFURA_PROJECT_ID"))

# Проверка подключения
if not w3.isConnected():
    print("❌ Не удалось подключиться к RPC")
else:
    print("✅ Подключение к RPC успешно")

# Адрес прокси-контракта
CONTRACT = "0xa91fF8b606BA57D8c6638Dd8CF3FC7eB15a9c634"

# Вставьте сюда ABI реализационного контракта
manual_abi = [
    {
        "inputs": [
            {"internalType": "bytes[]", "name": "data", "type": "bytes[]"}
        ],
        "name": "multicall",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    }
    # Добавьте остальные определения функций из ABI реализационного контракта
]

# Доступ к контракту с вручную заданным ABI
def access_Contract(contract):
    return w3.eth.contract(address=contract, abi=manual_abi)

# Выполнение multicall для одного кошелька
def multicall_for_wallet(wallet_address, private_key):
    print(f"🚀 Обработка кошелька: {wallet_address}")
    contract = access_Contract(CONTRACT)

    method_data = [
        "0xf39a19bf0000000000000000000000005990c2a11af316987d2d99fe8b813d7c1f0ba0d0"
    ]

    nonce = w3.eth.getTransactionCount(wallet_address)
    print(f"🔢 Nonce: {nonce}")

    txn = contract.functions.multicall(method_data).build_transaction({
        'from': wallet_address,
        'gas': 600000,
        'gasPrice': w3.toWei('0.01041', 'gwei'),
        'nonce': nonce,
    })

    signed_txn = w3.eth.account.sign_transaction(txn, private_key)
    print(f"✅ Транзакция подписана")

    tx_hash = w3.eth.send_raw_transaction(signed_txn.rawTransaction)
    print(f"✅ Транзакция отправлена для {wallet_address}. Hash: {tx_hash.hex()}")

    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    print(f"✅ Транзакция подтверждена для {wallet_address}: {receipt}")

# Чтение данных из CSV и выполнение multicall для каждого кошелька
def process_wallets():
    try:
        with open('wallets.csv', 'r') as file:
            print("✅ Файл wallets.csv успешно открыт")
            reader = csv.DictReader(file)
            for row in reader:
                address = row['address'].strip()
                private_key = row['private_key'].strip()

                if not private_key.startswith("0x"):
                    private_key = "0x" + private_key

                if len(private_key) != 66:
                    print(f"❌ Ошибка: Приватный ключ для {address} имеет неправильную длину ({len(private_key)}). Пропускаем.")
                    continue

                try:
                    multicall_for_wallet(address, private_key)
                except Exception as e:
                    print(f"❌ Ошибка при обработке {address}: {e}")
    except FileNotFoundError:
        print("❌ Файл wallets.csv не найден")

# Запуск обработки
process_wallets()
