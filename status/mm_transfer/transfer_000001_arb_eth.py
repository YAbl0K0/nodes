from web3 import Web3
import getpass

# RPC Arbitrum (можешь добавить свои)
RPC_URL = "https://arb1.arbitrum.io/rpc"
CHAIN_ID = 42161

# Сколько ETH отправлять (в ETH)
AMOUNT_TO_SEND = 0.00001

# Файл с адресами
ADDRESSES_FILE = "address_arb.txt"

# Создаем подключение
w3 = Web3(Web3.HTTPProvider(RPC_URL))
if not w3.is_connected():
    raise Exception("❌ Не удалось подключиться к RPC Arbitrum")

# Ввод приватного ключа (открыто)
private_key = input("Введите приватный ключ кошелька (он НЕ сохранится): ").strip()
account = w3.eth.account.from_key(private_key)
sender_address = account.address
print(f"Отправитель: {sender_address}")

# Загружаем адреса
with open(ADDRESSES_FILE, "r") as f:
    addresses = [line.strip() for line in f if line.strip()]

print(f"Найдено {len(addresses)} адресов для отправки.")

# Отправка средств
nonce = w3.eth.get_transaction_count(sender_address)
gas_price = w3.eth.gas_price

for address in addresses:
    try:
        tx = {
            'to': w3.to_checksum_address(address),
            'value': w3.to_wei(AMOUNT_TO_SEND, 'ether'),
            'gas': 21000,
            'gasPrice': gas_price,
            'nonce': nonce,
            'chainId': CHAIN_ID
        }

        signed_tx = w3.eth.account.sign_transaction(tx, private_key)
        tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
        print(f"✅ Отправлено {AMOUNT_TO_SEND} ETH на {address} | TX: {tx_hash.hex()}")
        nonce += 1

    except Exception as e:
        print(f"❌ Ошибка отправки на {address}: {e}")
