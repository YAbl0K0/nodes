import csv
import json
from web3 import Web3

# Подключение к RPC Arbitrum
w3 = Web3(Web3.HTTPProvider("https://arb-mainnet.g.alchemy.com/v2/CZp2sOzdTa1SZukXkVGpP0kpsyhJL5nL"))

# Проверка подключения
if not w3.is_connected():
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
]

# Доступ к контракту с вручную заданным ABI
def access_Contract(contract):
    return w3.eth.contract(address=contract, abi=manual_abi)

# Выполнение multicall для одного кошелька
def format_wallet_address(address: str) -> str:
    # Remove '0x' prefix
    address = address[2:]
    # Convert to lowercase
    address = address.lower()
    # Pad with leading zeros to ensure 96 characters length
    address = address.ljust(96, '0')
    return address

first_part = "f39a19bf000000000000000000000000"
wallet_address = "0x0FED18aB6A2CbC49B0E55a46b2926FBDe453a848"
formatted_address = format_wallet_address(wallet_address)

    # Concatenate both parts
combined_string = first_part + formatted_address

    # Split into two 64-character strings
part1 = combined_string[:64]
part2 = combined_string[64:]
array =["0000000000000000000000000000000000000000000000000000000000000020",
        "0000000000000000000000000000000000000000000000000000000000000001",
        "0000000000000000000000000000000000000000000000000000000000000020",
        "0000000000000000000000000000000000000000000000000000000000000024",
        part1,
        part2]
    
print(array)

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

                try:
                    multicall_for_wallet(address, private_key)
                except Exception as e:
                    print(f"❌ Ошибка при обработке {address}: {e}")
    except FileNotFoundError:
        print("❌ Файл wallets.csv не найден")

# Запуск обработки
process_wallets()
