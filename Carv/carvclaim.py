from web3 import Web3
import json
import requests
import time

# Підключення до RPC
w3 = Web3(Web3.HTTPProvider("https://arbitrum-mainnet.infura.io/v3/93ff81a0346847809ac76f699b69098c"))

# Дані контракту
CONTRACT = "0xa91fF8b606BA57D8c6638Dd8CF3FC7eB15a9c634"
ARBISCAN_API_KEY = "RVVY832DVQGA39F4IVC82615YYYIGUB1S2"

# Введіть ваш приватний ключ
PRIVATE_KEY = "YOUR_PRIVATE_KEY"
ACCOUNT = w3.eth.account.from_key(PRIVATE_KEY)
SENDER_ADDRESS = ACCOUNT.address

# Отримання ABI
def get_ABI(contract):
    url = f"https://api.arbiscan.io/api?module=contract&action=getabi&address={contract}&apikey={ARBISCAN_API_KEY}"
    response = requests.get(url)
    data = response.json()
    if data["status"] == "1":
        return json.loads(data["result"])
    else:
        raise ValueError("❌ Не вдалося отримати ABI")

# Доступ до контракту
def access_Contract(contract):
    abi = get_ABI(contract)
    return w3.eth.contract(address=contract, abi=abi)

# Виконання multicall
def multicall():
    contract = access_Contract(CONTRACT)

    # Аргументи для виклику nodeClaim
    method_id = "0xf39a19bf"  # methodId для nodeClaim(address,uint256)
    node_address = "5990c2a11af316987d2d99fe8b813d7c1f0ba0d0"
    node_address_padded = node_address.rjust(64, '0')

    # Наприклад, нагорода у wei
    rewards = w3.toWei("690.810218900826266814", "ether")
    rewards_padded = hex(rewards)[2:].rjust(64, '0')

    # Формування даних
    data = method_id + node_address_padded + rewards_padded

    # Перетворення в байти
    data_bytes = bytes.fromhex(data[2:] if data.startswith("0x") else data)

    # Побудова транзакції
    txn = contract.functions.multicall([data_bytes]).build_transaction({
        'from': SENDER_ADDRESS,
        'gas': 800000,
        'gasPrice': w3.toWei('10', 'gwei'),
        'nonce': w3.eth.get_transaction_count(SENDER_ADDRESS),
    })

    # Підписання транзакції
    signed_txn = w3.eth.account.sign_transaction(txn, private_key=PRIVATE_KEY)

    # Відправка транзакції
    tx_hash = w3.eth.send_raw_transaction(signed_txn.rawTransaction)
    print(f"Транзакція надіслана: {tx_hash.hex()}")

    # Очікування підтвердження
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    print("✅ Транзакція підтверджена:", receipt)

multicall()
