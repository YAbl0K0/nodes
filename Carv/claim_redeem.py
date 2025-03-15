import csv
import json
from web3 import Web3
from eth_abi import encode

# Підключення до RPC Arbitrum
w3 = Web3(Web3.HTTPProvider("https://arb-mainnet.g.alchemy.com/v2/CZp2sOzdTa1SZukXkVGpP0kpsyhJL5nL"))

# Перевірка підключення
if not w3.is_connected():
    print("❌ Не вдалося підключитися до RPC")
else:
    print("✅ Підключення до RPC успішне")

# Адреса контракту
CONTRACT = "0xa91fF8b606BA57D8c6638Dd8CF3FC7eB15a9c634"

# ABI контракту
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
]

# Доступ до контракту
def access_contract(contract):
    return w3.eth.contract(address=contract, abi=manual_abi)

# Форматування адреси гаманця
def format_wallet_address(address: str) -> str:
    address = address[2:].lower()
    return address.rjust(64, '0')

# Формування multicall даних
def prepare_multicall_data(method_id, wallet_address):

    # Формування байтового масиву
    first_part = "f39a19bf000000000000000000000000"
    wallet_address = "0x0FED18aB6A2CbC49B0E55a46b2926FBDe453a848"
    formatted_address = format_wallet_address(wallet_address)
    function_data = first_part + formatted_address
    multicall_data = encode(['bytes'], [bytes.fromhex(function_data)])

    print(type(multicall_data))
# Виконання multicall для одного гаманця
def multicall_for_wallet(wallet_address, private_key):
    contract = access_contract(CONTRACT)

    # Підготовка даних
    method_id = "f39a19bf"
    multicall_data = prepare_multicall_data(method_id, wallet_address)

    # Виклик encodeABI через функцію multicall
    call_data = contract.functions.multicall(multicall_data).build_transaction({
        "from": wallet_address,
        "nonce": w3.eth.get_transaction_count(wallet_address),
        "gas": 800000,
        "gasPrice": w3.to_wei('10', 'gwei'),
        "chainId": 42161  # Arbitrum One
    })
    
    print(type(multicall_data))
    # Підпис транзакції
    signed_txn = w3.eth.account.sign_transaction(call_data, private_key)
    print(f"✅ Транзакція підписана для {wallet_address}")

    # Відправка транзакції
    tx_hash = w3.eth.send_raw_transaction(signed_txn.rawTransaction)
    print(f"✅ Транзакція відправлена для {wallet_address}. Hash: {tx_hash.hex()}")

    # Очікування підтвердження
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    print(f"✅ Транзакція підтверджена для {wallet_address}: {receipt}")

# Читання даних з CSV та виконання multicall
def process_wallets():
    try:
        with open('wallets.csv', 'r') as file:
            print("✅ Файл wallets.csv успішно відкритий")
            reader = csv.DictReader(file)
            for row in reader:
                address = row['address'].strip()
                private_key = row['private_key'].strip()

                if not private_key.startswith("0x"):
                    private_key = "0x" + private_key

                try:
                    multicall_for_wallet(address, private_key)
                except Exception as e:
                    print(f"❌ Помилка при обробці {address}: {e}")
    except FileNotFoundError:
        print("❌ Файл wallets.csv не знайдено")

# Запуск обробки
process_wallets()
